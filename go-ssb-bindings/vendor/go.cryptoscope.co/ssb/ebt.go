// SPDX-License-Identifier: MIT

package ssb

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	refs "go.mindeco.de/ssb-refs"
)

// NetworkFrontier represents a set of feeds and their length
// The key is the canonical string representation (feed.Ref())
type NetworkFrontier map[string]Note

// Note informs about a feeds length and some control settings
type Note struct {
	Seq int64

	// Replicate (seq==-1) tells the peer that it doesn't want to hear about that feed
	Replicate bool

	// Receive controlls the eager push.
	// a peer might want to know if there are updates but not directly get the messages
	Receive bool
}

func (s Note) MarshalJSON() ([]byte, error) {
	var i int64
	if !s.Replicate {
		return []byte("-1"), nil
	}
	i = int64(s.Seq)
	if i == -1 { // -1 is margarets way of saying "no msgs in this feed"
		i = 0
	}
	i = i << 1 // times 2 (to make room for the rx bit)
	if s.Receive {
		i |= 0
	} else {
		i |= 1
	}
	return []byte(strconv.FormatInt(i, 10)), nil
}

func (nf *NetworkFrontier) UnmarshalJSON(b []byte) error {
	var dummy map[string]int64

	if err := json.Unmarshal(b, &dummy); err != nil {
		return err
	}

	var newMap = make(NetworkFrontier, len(dummy))
	for fstr, i := range dummy {
		// validate
		feed, err := refs.ParseFeedRef(fstr)
		if err != nil {
			// just skip invalid feeds
			continue
		}

		if feed.Algo() != refs.RefAlgoFeedSSB1 {
			// skip other formats (TODO: gg support)
			continue
		}

		var s Note
		s.Replicate = i != -1
		s.Receive = !(i&1 == 1)
		s.Seq = int64(i >> 1)

		newMap[fstr] = s
	}

	*nf = newMap
	return nil
}

func (nf NetworkFrontier) String() string {
	var sb strings.Builder
	sb.WriteString("## Network Frontier:\n")
	for feed, seq := range nf {
		fmt.Fprintf(&sb, "\t%s:%+v\n", feed, seq)
	}
	return sb.String()
}
