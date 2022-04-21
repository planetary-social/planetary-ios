package migrations

import (
	"context"
	"fmt"
	"go.cryptoscope.co/ssb/multilogs"
	"io"
	"io/ioutil"
	"log"
	"os"
	"strconv"
	"time"
	legacy2 "verseproj/scuttlegobridge/migrations/legacy"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/margaret"
	refs "go.mindeco.de/ssb-refs"

	"github.com/cryptix/go/logging"
	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret/codec/msgpack"
	"go.cryptoscope.co/margaret/offset2"
	"go.cryptoscope.co/ssb/message/legacy"
	"go.cryptoscope.co/ssb/repo"
)

func StillUsingBadger(log logging.Interface, r repo.Interface) (bool, error) {
	v := CurrentVersion(r)
	switch {
	case v == 1:
		// do the deed
	case v < 1:
		log.Log("event", "repo is not version 1 yet", "v", v)
		return false, nil
	default:
		return false, errors.Errorf("sbot/repo migrate: invalid version: %d", v)
	}

	// check the db and the state file
	var hasDB, hasState bool

	dbPath := r.GetPath(repo.PrefixMultiLog, multilogs.IndexNameFeeds, "db")
	_, err := os.Stat(dbPath)
	if err != nil && !os.IsNotExist(err) {
		return false, errors.Wrap(err, "StillUsingBadger: failed to check old db path inside the repo")
	}
	if err == nil {
		hasDB = true
	}

	stateFilePath := r.GetPath(repo.PrefixMultiLog, multilogs.IndexNameFeeds, "state.json")
	_, err = os.Stat(stateFilePath)
	if err != nil && !os.IsNotExist(err) {
		return false, errors.Wrap(err, "StillUsingBadger: failed to check old state file path inside the repo")
	}
	if err == nil {
		hasState = true
	}

	return hasDB && hasState, nil
}

func CurrentVersion(r repo.Interface) int {
	version, err := ioutil.ReadFile(r.GetPath("version"))
	if os.IsNotExist(err) {
		return 0
	} else if err != nil {
		log.Println("CurrentVersion error:", err)
		return -1
	}
	v, err := strconv.Atoi(string(version))
	if err != nil {
		log.Printf("CurrentVersion failed to parse file content (%q):%s", string(version), err)
		return -1
	}
	return v
}

// SetVersion should be atomic
func SetVersion(r repo.Interface, to int) error {
	fname := r.GetPath("version")
	vstr := []byte(strconv.Itoa(to))
	err := ioutil.WriteFile(fname, vstr, 0700)
	return errors.Wrap(err, "SetVersion failed to write file")
}

func UpgradeToMultiMessage(log logging.Interface, r repo.Interface) (bool, error) {
	v := CurrentVersion(r)
	switch {
	case v == 0:
		// do the deed
	case v > 0:
		log.Log("level", "info", "msg", "repo already updated", "v", v)
		return false, nil
	default:
		return false, errors.Errorf("sbot/repo migrate: invalid version: %d", v)
	}

	from, err := checkIfVersion0(r, log)
	if err != nil {
		return false, errors.Wrap(err, "pre-check failed failed")
	}

	to, err := repo.OpenLog(r, "migrate-v1")
	if err != nil {
		return false, errors.Wrap(err, "error opening new log")
	}

	gotMsgs, err := copyOffset(log, from, to)
	if err != nil {
		return false, errors.Wrap(err, "error copying new log")
	}

	if err := validateNewLog(log, gotMsgs, to); err != nil {
		return false, errors.Wrap(err, "error validating new log")
	}

	err = from.(io.Closer).Close()
	if err != nil {
		return false, errors.Wrap(err, "error closing from log")
	}
	err = to.(io.Closer).Close()
	if err != nil {
		return false, errors.Wrap(err, "error closing to log")
	}

	err = os.Rename(r.GetPath("log"), r.GetPath("log-bak-v0"))
	if err != nil {
		return false, errors.Wrap(err, "error moving old log into backup position")
	}

	err = os.Rename(r.GetPath("logs", "migrate-v1"), r.GetPath("log"))
	if err != nil {
		return false, errors.Wrap(err, "error moving migrated log into position")
	}

	return true, SetVersion(r, 1)
}

func checkIfVersion0(r repo.Interface, log logging.Interface) (margaret.Log, error) {
	fromPath := r.GetPath("log")
	from, err := offset2.Open(fromPath, msgpack.New(&legacy2.OldStoredMessage{}))
	if err != nil {
		return nil, errors.Wrap(err, "check-v0: failed to open source log")
	}

	fromSeq := from.Seq()

	if fromSeq == margaret.SeqEmpty {
		// empty source, totally fine, just make a new empty one
		return from, nil
	}

	// simple check if we have a valid msg
	v, err := from.Get(0)
	if err != nil {
		return nil, errors.Wrap(err, "check-v0: failed to get first message")
	}
	osm, ok := v.(legacy2.OldStoredMessage)
	if !ok {
		return nil, errors.Errorf("check-v0: wrong type: %T", v)
	}

	ref, _, err := legacy.Verify(osm.Raw, nil) // hmac stuff grm... TODO: env var?!
	if err != nil {
		return nil, errors.Wrap(err, "check-v0: verify failed")
	}

	if osm.Key == nil {
		return nil, errors.Errorf("check-v0: osm key is nil")
	}

	if !ref.Equal(*osm.Key) {
		return nil, errors.Errorf("check-v0: msg key and verifyied msg didn't line up?!")
	}
	return from, nil
}

func copyOffset(log logging.Interface, from, to margaret.Log) ([]refs.MessageRef, error) {
	fromSeq := from.Seq()

	fromSrc, err := from.Query()
	if err != nil {
		return nil, errors.Wrap(err, "upgrade-v0: failed to construct query on from")
	}

	start := time.Now()

	i := 0
	took := time.Now()
	onePercent := fromSeq / 10

	var got []refs.MessageRef
	track := luigi.FuncSink(func(ctx context.Context, v interface{}, err error) error {
		if luigi.IsEOS(err) { // || margaret.IsErrNulled(err)
			return nil
		}
		if err != nil {
			return errors.Wrap(err, "pump failed")
		}

		msg := v.(legacy2.OldStoredMessage)

		got = append(got, *msg.Key)

		seq, err := to.Append(v)
		if seq%onePercent == 0 {
			log.Log("level", "debug", "msg", "copy progress", "left", fromSeq-seq, "i", i, "took", time.Since(took))
			i++
			took = time.Now()
		}
		return err
	})

	log.Log("event", "start-copy", "seq", fromSeq)
	err = luigi.Pump(context.TODO(), track, fromSrc)
	if err != nil {
		return nil, errors.Wrap(err, "migrate: pumping messages failed")
	}
	log.Log("event", "copy-done", "took", time.Since(start))

	return got, nil
}

func validateNewLog(log logging.Interface, got []refs.MessageRef, to margaret.Log) error {
	toSeq := to.Seq()
	log.Log("event", "validating", "target has", toSeq)

	newTarget, err := to.Query()
	if err != nil {
		return err
	}
	start := time.Now()
	i := 0
	n := len(got)
	onePercent := n / 10
	for {
		v, err := newTarget.Next(context.TODO())
		if luigi.IsEOS(err) {
			break
		} else if err != nil {
			return err
		}

		msg := v.(refs.Message)

		if !got[i].Equal(msg.Key()) {
			return fmt.Errorf("migrate failed - msg%d diverges", i)
		}
		if i%onePercent == 0 {
			log.Log("level", "debug", "msg", "validate progress", "left", n-i)
		}
		i++
	}

	log.Log("event", "hash-check-done", "took", time.Since(start))
	return nil
}
