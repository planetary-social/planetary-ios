package repo

import (
	"context"
	"fmt"

	"go.cryptoscope.co/luigi"
	"go.cryptoscope.co/luigi/mfr"
	"go.cryptoscope.co/margaret"
	refs "go.mindeco.de/ssb-refs"
)

// FilterFunc works on messages of a FilteredLog. If the func returns true, the log is in the filtered log.
type FilterFunc func(refs.Message) bool

// NewFilteredLog wraps the passed log into a new one, using the FilterFunc to decide if a message is in the log.
func NewFilteredLog(b margaret.Log, fn FilterFunc) margaret.Log {
	return FilteredLog{
		backing: b,
		filter:  fn,
	}
}

// FilteredLog omits entries in the backing log as decided by the configured FilterFunc.
// It does so by claiming the entries are deleted (via returning margaret.ErrNulled instead)
type FilteredLog struct {
	backing margaret.Log

	filter FilterFunc
}

func (fl FilteredLog) Seq() int64 { return fl.backing.Seq() }

func (fl FilteredLog) Changes() luigi.Observable { return fl.backing.Changes() }

// Get retrieves the message object by traversing the authors sublog to the root log
func (fl FilteredLog) Get(s int64) (interface{}, error) {
	v, err := fl.backing.Get(s)
	if err != nil {
		return nil, fmt.Errorf("filtered get: failed to retrieve sequence for the root log: %w", err)
	}
	switch tv := v.(type) {
	case error:
		return tv, nil
	case refs.Message:
		if okay := fl.filter(tv); !okay {
			return margaret.ErrNulled, nil
		}
		return tv, nil
	default:
		return nil, fmt.Errorf("unhandled message type: %T", v)
	}
}

func (fl FilteredLog) Query(qry ...margaret.QuerySpec) (luigi.Source, error) {
	src, err := fl.backing.Query(qry...)
	if err != nil {
		return nil, err
	}
	filterdSrc := mfr.SourceFilter(src, func(ctx context.Context, v interface{}) (bool, error) {
		sw := v.(margaret.SeqWrapper)
		iv := sw.Value()

		switch tv := iv.(type) {

		case error:
			if margaret.IsErrNulled(tv) {
				return false, nil
			}
			return false, tv
		case refs.Message:
			if okay := fl.filter(tv); !okay {
				return false, nil
			}
			return true, nil
		default:
			return false, fmt.Errorf("unhandled message type: %T", v)
		}
	})
	return filterdSrc, nil
}

func (fl FilteredLog) Append(val interface{}) (int64, error) {
	return -2, fmt.Errorf("FitleredLog is read-only")
}
