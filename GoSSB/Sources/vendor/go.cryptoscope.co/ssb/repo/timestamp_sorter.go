// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package repo

import (
	"context"
	"encoding/binary"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"sort"
	"time"

	bmap "github.com/dgraph-io/sroar"
	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"

	refs "go.mindeco.de/ssb-refs"
)

// SortedSequence holds the sequence value of the message and the domain value it should be sorted by.
type SortedSequence struct {
	By  int64 // fill with the value of the domain
	Seq int64 // the sequence of the entry we are looking for
}

// SortedSeqSlice a slice of SortedSequences that can be sorted
type SortedSeqSlice []SortedSequence

func (ts SortedSeqSlice) Len() int { return len(ts) }

// Swap swaps the elements with indexes i and j.
func (ts SortedSeqSlice) Swap(i int, j int) {
	ts[i], ts[j] = ts[j], ts[i]
}

// AsLuigiSource returns a luigi.Source to iterate over the sorted array.
// Helpful for retrofitting into existing margaret code.
func (ts SortedSeqSlice) AsLuigiSource() luigi.Source {
	return &sortedSource{
		elems: ts,
	}
}

type sortedSource struct{ elems SortedSeqSlice }

func (ss *sortedSource) Next(_ context.Context) (interface{}, error) {
	if len(ss.elems) == 0 {
		return nil, luigi.EOS{}
	}
	next := ss.elems[0]
	ss.elems = ss.elems[1:]
	return next, nil
}

// SortedAscending wraps around SortedSeqSlice to give it a Less that sorts values from small to large.
type SortedAscending struct{ SortedSeqSlice }

// Less sorts values up
func (ts SortedAscending) Less(i int, j int) bool {
	vi := ts.SortedSeqSlice[i]
	vj := ts.SortedSeqSlice[j]
	return vi.By < vj.By
}

// SortedDescending wraps around SortedSeqSlice to give it a Less that sorts values from large to small.
type SortedDescending struct{ SortedSeqSlice }

// Less sorts values down
func (ts SortedDescending) Less(i int, j int) bool {
	vi := ts.SortedSeqSlice[i]
	vj := ts.SortedSeqSlice[j]
	return vi.By > vj.By
}

// SequenceResolver holds three gigantic arrays for each of the understood ResolveDomains.
//
// It should be hooked into a receive log, and filled with Append.
//
// TODO: a better approach might be to fetch these lazyly from disk if they become too large.
// At 1mio messages we roughly look at 8mb per domain.
type SequenceResolver struct {
	seq2claimed  []int64
	seq2received []int64
	seq2feedseq  []int64

	dirty bool      // has not been written to disk yet
	repo  Interface // where to store the arrays
}

// NewSequenceResolver opens the stored resolver at r.GetPath("seqmaps") and Loads existing values.
func NewSequenceResolver(r Interface) (*SequenceResolver, error) {
	var sr SequenceResolver
	sr.repo = r

	_, err := sr.Load()
	if err != nil {
		return nil, fmt.Errorf("seq resolver: failed to load: %w", err)
	}

	return &sr, nil
}

// NewSequenceResolverFromLog creates a fresh resolver reading the full margaret log.
// Expects to read refs.Message from the log.
// Useful for testing.
func NewSequenceResolverFromLog(l margaret.Log) (*SequenceResolver, error) {
	ctx := context.Background()

	start := time.Now()

	var sr SequenceResolver

	src, err := l.Query()
	if err != nil {
		return nil, err
	}

	for {
		v, err := src.Next(ctx)
		if err != nil {
			if luigi.IsEOS(err) {
				break
			}
			return nil, err
		}

		msg, ok := v.(refs.Message)
		if !ok {
			return nil, fmt.Errorf("ts: wrong type: %T", v)
		}

		// TODO: seqWrap and use sr.Append()
		sr.seq2claimed = append(sr.seq2claimed, msg.Claimed().Unix())
		sr.seq2received = append(sr.seq2received, msg.Received().Unix())
		sr.seq2feedseq = append(sr.seq2feedseq, msg.Seq())
	}

	took := time.Since(start)
	fmt.Println("resolving all claimed time took: ", took)
	return &sr, nil
}

// ResolverFilter get's passed the value from the domain that is searched.
// Should return true if the value should be included and sorted
type ResolverFilter func(int64) bool

// SortDomain an enum for the understood domains
type SortDomain uint

// The known domains are: Claimed timestamp, Received Timestamp
// and Sequence number of the messageon the feed (this is important for partial replication, where feeds are not fetched in full and correct order)
const (
	_ SortDomain = iota
	SortByClaimed
	SortByReceived
	SortByFeedSeq
)

// TODO: maybe some utilities, OTOH it's just generating the seq array
// func (sr SequenceResolver) SortByRange(from, to, by, ok) ...

func (sr SequenceResolver) prepare(by SortDomain) ([]int64, int64, error) {
	err := sr.checkConsistency()
	if err != nil {
		return nil, -2, err
	}
	max := int64(len(sr.seq2claimed)) - 1
	// select the array that should be searched
	var domain []int64
	switch by {
	case SortByClaimed:
		domain = sr.seq2claimed
	case SortByReceived:
		domain = sr.seq2received
	case SortByFeedSeq:
		domain = sr.seq2feedseq
	default:
		return nil, -2, fmt.Errorf("seq resolver: invalid domain: %d", by)
	}

	return domain, max, nil
}

func (sr SequenceResolver) SortAndFilterBitmap(seqs *bmap.Bitmap, by SortDomain, ok ResolverFilter, desc bool) (SortedSeqSlice, error) {
	domain, max, err := sr.prepare(by)
	if err != nil {
		return nil, err
	}

	var result SortedSeqSlice

	it := seqs.NewIterator()

	// pick and filter
	for it.HasNext() {
		s := int64(it.Next())

		if s < 0 || s > max {
			return nil, fmt.Errorf("seq resolver: out of bounds (%d - %d)", s, max)
		}

		sortme := SortedSequence{Seq: s}

		sortme.By = domain[s]

		if ok(sortme.By) {
			result = append(result, sortme)
		}
	}

	if desc {
		sort.Sort(SortedDescending{result})
	} else {
		sort.Sort(SortedAscending{result})
	}

	return result, nil
}

func (sr SequenceResolver) SortAndFilterAll(by SortDomain, ok ResolverFilter, desc bool) (SortedSeqSlice, error) {
	domain, _, err := sr.prepare(by)
	if err != nil {
		return nil, err
	}

	var result SortedSeqSlice

	// pick and filter
	for s := range sr.seq2claimed { // which array doesnt matter since they are all of the same length
		sortme := SortedSequence{Seq: int64(s)}

		sortme.By = domain[s]

		if ok(sortme.By) {
			result = append(result, sortme)
		}
	}

	if desc {
		sort.Sort(SortedDescending{result})
	} else {
		sort.Sort(SortedAscending{result})
	}

	return result, nil
}

// SortAndFilter goes through seqs in the passed domain using the filter function to include wanted elements.
// desc: true means descending, desc: false means ascending.
func (sr SequenceResolver) SortAndFilter(seqs []int64, by SortDomain, ok ResolverFilter, desc bool) (SortedSeqSlice, error) {
	domain, max, err := sr.prepare(by)
	if err != nil {
		return nil, err
	}

	var result SortedSeqSlice

	// pick and filter
	for _, s := range seqs {
		sortme := SortedSequence{Seq: s}

		if s < 0 || s > max {
			return nil, fmt.Errorf("seq resolver: out of bounds (%d - %d)", s, max)
		}

		sortme.By = domain[s]

		if ok(sortme.By) {
			result = append(result, sortme)
		}
	}

	if desc {
		sort.Sort(SortedDescending{result})
	} else {
		sort.Sort(SortedAscending{result})
	}

	return result, nil
}

func (sr *SequenceResolver) checkConsistency() error {
	n := len(sr.seq2claimed)
	m := len(sr.seq2received)
	o := len(sr.seq2feedseq)

	if n != m {
		return fmt.Errorf("seq resolver: consistency error (claimed:%d, received:%d)", n, m)
	}

	if n != o {
		return fmt.Errorf("seq resolver: consistency error (timestamps:%d, feedseq:%d)", n, o)
	}

	return nil
}

// Append adds all three domains to the resolver.
func (sr *SequenceResolver) Append(seq int64, feed int64, claimed, received time.Time) error {
	if err := sr.checkConsistency(); err != nil {
		return err
	}

	if has := int64(len(sr.seq2claimed)); has != seq {
		if seq < has {
			// assuming reindex - value wouldnt change
			// TODO: maybe received? but not really...
			// could be  a side-channel for _new messages_
			// but it's a dirty hack - rather use _readable index_ message count
			return nil
		}
		return fmt.Errorf("seq resolver: would break const (has:%d, will: %d)", has, seq)
	}

	sr.seq2claimed = append(sr.seq2claimed, claimed.Unix())
	sr.seq2received = append(sr.seq2received, received.Unix())
	sr.seq2feedseq = append(sr.seq2feedseq, feed)

	sr.dirty = true
	return nil
}

func (sr SequenceResolver) String() string {
	return fmt.Sprintf("seq resolver: %d elements", len(sr.seq2claimed))
}

// Load reads the files from repo and deserializes them.
func (sr *SequenceResolver) Load() (int64, error) {
	if sr.repo == nil {
		return -1, fmt.Errorf("seq resolver: not initialized with repo to read from")
	}

	var idxes = []struct {
		name string
		arr  *[]int64
	}{
		{"ts-claimed", &sr.seq2claimed},
		{"ts-received", &sr.seq2received},
		{"feed-seqs", &sr.seq2feedseq},
	}

	for _, idx := range idxes {
		f, err := os.Open(sr.indexPath(idx.name))
		if err != nil {
			if os.IsNotExist(err) {
				return 0, nil
			}
			return -1, fmt.Errorf("seq resolver: failed to create temp file for %s: %w", idx.name, err)
		}

		stat, err := f.Stat()
		if err != nil {
			return -1, fmt.Errorf("seq resolver: failed stat data file %s: %w", idx.name, err)
		}

		var arr = make([]int64, stat.Size()/8)
		err = binary.Read(f, binary.BigEndian, arr)
		if err != nil {
			return -1, fmt.Errorf("seq resolver: failed to encode array of %s: %w", idx.name, err)
		}

		err = f.Close()
		if err != nil {
			return -1, fmt.Errorf("seq resolver: failed to close temfile for %s: %w", idx.name, err)
		}

		*idx.arr = arr
	}
	if err := sr.checkConsistency(); err != nil {
		return -1, err
	}

	return int64(len(sr.seq2claimed)), nil
}

func (sr *SequenceResolver) indexPath(name string) string {
	return sr.repo.GetPath(PrefixIndex, "seqmaps", name)
}

// Serialize does the reverse from Load. It saves the three domains to disk.
func (sr *SequenceResolver) Serialize() error {
	if err := sr.checkConsistency(); err != nil {
		return err
	}

	os.MkdirAll(filepath.Dir(sr.indexPath("create.dir")), 0700)

	var idxes = []struct {
		name string
		arr  []int64
	}{
		{"ts-claimed", sr.seq2claimed},
		{"ts-received", sr.seq2received},
		{"feed-seqs", sr.seq2feedseq},
	}

	for _, idx := range idxes {
		f, err := ioutil.TempFile("", idx.name+"-*")
		if err != nil {
			return fmt.Errorf("seq resolver: failed to create temp file for %s: %w", idx.name, err)
		}

		err = binary.Write(f, binary.BigEndian, idx.arr)
		if err != nil {
			return fmt.Errorf("seq resolver: failed to encode array of %s: %w", idx.name, err)
		}

		err = f.Close()
		if err != nil {
			return fmt.Errorf("seq resolver: failed to close temfile for %s: %w", idx.name, err)
		}

		err = moveFile(f.Name(), sr.indexPath(idx.name))
		if err != nil {
			return fmt.Errorf("seq resolver: failed to move updated file in place %s: %w", idx.name, err)
		}
	}
	sr.dirty = false
	return nil
}

// Seq returns the number of entries held by the resolver.
func (sr SequenceResolver) Seq() int64 {
	err := sr.checkConsistency()
	if err != nil {
		panic(err)
	}

	return int64(len(sr.seq2claimed))
}

// Close serialzes the resolver to disk.
func (sr SequenceResolver) Close() error {
	return sr.Serialize()
}

// util

// os.Rename doesn't work across filesystems.
// /tmp is often on tmpfs or similar.
func moveFile(sourcePath, destPath string) error {
	inputFile, err := os.Open(sourcePath)
	if err != nil {
		return fmt.Errorf("failed to open source file: %s", err)
	}
	outputFile, err := os.Create(destPath)
	if err != nil {
		inputFile.Close()
		return fmt.Errorf("failed to open dest file: %s", err)
	}
	defer outputFile.Close()
	_, err = io.Copy(outputFile, inputFile)
	inputFile.Close()
	if err != nil {
		return fmt.Errorf("Writing to output file failed: %s", err)
	}
	// The copy was successful, so now delete the original file
	err = os.Remove(sourcePath)
	if err != nil {
		return fmt.Errorf("Failed removing original file: %s", err)
	}
	return nil
}
