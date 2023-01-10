package main

import "C"
import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"github.com/go-kit/kit/log/level"
	"github.com/pkg/errors"
	"github.com/planetary-social/scuttlego/service/app/common"
	"github.com/planetary-social/scuttlego/service/app/queries"
	"time"
)

// ssbStreamRootLog returns received messages. Only messages with a sequence
// greater or equal to the given sequence are returned. This sequence is not
// the sequence field of Scuttlebutt messages and is simply an index of a
// message in a list of all received messages. This sequence starts at 0.
// Number of returned messages can be limited. Limit must be a positive number.
//
//export ssbStreamRootLog
func ssbStreamRootLog(startSeq int64, limit int) *C.char {
	var err error
	defer logError("ssbStreamRootLog", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return nil
	}

	receiveLogSequence, err := common.NewReceiveLogSequence(int(startSeq))
	if err != nil {
		err = errors.Wrap(err, "could not create a receive log sequence")
		return nil
	}

	query, err := queries.NewReceiveLog(
		receiveLogSequence,
		limit,
	)
	if err != nil {
		err = errors.Wrap(err, "could not create a query")
		return nil
	}

	start := time.Now()

	msgs, err := service.App.Queries.ReceiveLog.Handle(query)
	if err != nil {
		err = errors.Wrap(err, "query failed")
		return nil
	}

	level.Debug(log).Log("event", "returning new messages in ssbStreamRootLog", "n", len(msgs), "duration", time.Since(start).Seconds())

	var buf bytes.Buffer
	err = marshalAsLog(&buf, msgs)
	if err != nil {
		err = errors.Wrap(err, "marshaling failed")
		return nil
	}

	return C.CString(buf.String())
}

//export ssbStreamPrivateLog
func ssbStreamPrivateLog(seq uint64, limit int) *C.char {
	return C.CString("[]")
}

// ssbStreamPublishedLog returns messages published by the current active
// identity. Only messages with a sequence greater than the sequence of a message
// pointed to by the provided receive log sequence are returned. This sequence
// is not the sequence field of Scuttlebutt messages and is simply an index of a message in a list of all received
// messages. This means that receive log and published log share the sequence numbers. This
// sequence starts at 0. In order to get the first message you need to pass -1 to this function.
// The provided sequence must be a sequence of a message belonging to the feed of the currently active local identity.
//
//export ssbStreamPublishedLog
func ssbStreamPublishedLog(afterSeq int64) *C.char {
	var err error
	defer logError("ssbStreamPublishedLog", &err)

	service, err := node.Get()
	if err != nil {
		err = errors.Wrap(err, "could not get the node")
		return nil
	}

	query := queries.PublishedLog{
		LastSeq: nil,
	}

	if afterSeq >= 0 {
		sequence, err := common.NewReceiveLogSequence(int(afterSeq))
		if err != nil {
			err = errors.Wrap(err, "failed to create a message sequence")
			return nil
		}
		query.LastSeq = &sequence
	}

	start := time.Now()

	msgs, err := service.App.Queries.PublishedLog.Handle(query)
	if err != nil {
		err = errors.Wrap(err, "command failed")
		return nil
	}

	level.Debug(log).Log("event", "returning new messages in ssbStreamPublishedLog", "n", len(msgs), "duration", time.Since(start).Seconds())

	var buf bytes.Buffer
	err = marshalAsLog(&buf, msgs)
	if err != nil {
		err = errors.Wrap(err, "marshaling failed")
		return nil
	}

	return C.CString(buf.String())
}

func marshalAsLog(buf *bytes.Buffer, msgs []queries.LogMessage) error {
	result := make([]logEntry, 0) // prevent empty arrays rendering as null

	for _, logMsg := range msgs {
		hasher := sha256.New()
		hasher.Write([]byte(logMsg.Message.Id().String()))

		entry := logEntry{
			Key:           logMsg.Message.Id().String(),
			Value:         logMsg.Message.Raw().Bytes(),
			Timestamp:     time.Now().UnixMilli(),
			ReceiveLogSeq: int64(logMsg.Sequence.Int()),
			HashedKey:     fmt.Sprintf("%x", hasher.Sum(nil)),
		}

		result = append(result, entry)
	}

	if err := json.NewEncoder(buf).Encode(result); err != nil {
		return errors.Wrap(err, "json marshaling failed")
	}

	return nil
}

type logEntry struct {
	Key           string          `json:"key"`
	Value         json.RawMessage `json:"value"`
	Timestamp     int64           `json:"timestamp"`
	ReceiveLogSeq int64           `json:"ReceiveLogSeq"`
	HashedKey     string          `json:"HashedKey"`
}
