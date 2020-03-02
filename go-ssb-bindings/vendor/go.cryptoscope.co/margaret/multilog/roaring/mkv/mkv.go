package mkv

import (
	"go.cryptoscope.co/margaret/internal/persist/mkv"
	"go.cryptoscope.co/margaret/multilog/roaring"
)

func NewMultiLog(base string) (*roaring.MultiLog, error) {
	s, err := mkv.New(base)
	if err != nil {
		return nil, err
	}
	return roaring.NewStore(s), nil
}
