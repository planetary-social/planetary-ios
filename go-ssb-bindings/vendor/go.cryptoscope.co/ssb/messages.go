// SPDX-License-Identifier: MIT

package ssb

import (
	"encoding/json"
	"time"

	"github.com/cryptix/go/encodedTime"
	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
)

type Value struct {
	Previous  *MessageRef           `json:"previous"`
	Author    FeedRef               `json:"author"`
	Sequence  margaret.BaseSeq      `json:"sequence"`
	Timestamp encodedTime.Millisecs `json:"timestamp"`
	Hash      string                `json:"hash"`
	Content   json.RawMessage       `json:"content"`
	Signature string                `json:"signature"`
}

// Message allows accessing message aspects without known the feed type
type Message interface {
	Key() *MessageRef
	Previous() *MessageRef

	margaret.Seq

	Claimed() time.Time
	Received() time.Time

	Author() *FeedRef
	ContentBytes() []byte

	ValueContent() *Value
	ValueContentJSON() json.RawMessage
}

// DropContentRequest has special meaning on a gabby-grove feed.
// It's signature verification allows ommiting the content.
// A feed author can ask other peers to drop a previous message of theirs with this.
// Sequence must be smaller then current, also the targeted message can't be a drop-content-request
type DropContentRequest struct {
	Type     string     `json:"type"`
	Sequence uint       `json:"sequence"`
	Hash     MessageRef `json:"hash"`
}

const DropContentRequestType = "drop-content-request"

func NewDropContentRequest(seq uint, h MessageRef) *DropContentRequest {
	return &DropContentRequest{
		Type:     DropContentRequestType,
		Sequence: seq,
		Hash:     h,
	}
}

func (dcr DropContentRequest) Valid(log margaret.Log) bool {
	if dcr.Sequence < 1 {
		return false
	}

	msgv, err := log.Get(margaret.BaseSeq(dcr.Sequence - 1))
	if err != nil {
		return false
	}

	msg, ok := msgv.(Message)
	if !ok {
		return false
	}

	if msg.Author().Algo != RefAlgoFeedGabby {
		return false
	}

	match := msg.Key().Equal(dcr.Hash)
	if !match {
		return false
	}

	// check we can't delete deletes
	var msgType struct {
		Type string `json:"type"`
	}
	if err := json.Unmarshal(msg.ContentBytes(), &msgType); err != nil {
		return false
	}
	if msgType.Type == DropContentRequestType {
		return false
	}

	return true
}

type Contact struct {
	Type      string   `json:"type"`
	Contact   *FeedRef `json:"contact"`
	Following bool     `json:"following"`
	Blocking  bool     `json:"blocking"`
}

func NewContactFollow(who *FeedRef) *Contact {
	return &Contact{
		Type:      "contact",
		Contact:   who,
		Following: true,
	}
}

func NewContactBlock(who *FeedRef) *Contact {
	return &Contact{
		Type:     "contact",
		Contact:  who,
		Blocking: true,
	}
}

func (c *Contact) UnmarshalJSON(b []byte) error {
	var priv string
	err := json.Unmarshal(b, &priv)
	if err == nil {
		return ErrWrongType{want: "contact", has: "private.box?"}
	}

	var potential map[string]interface{}
	err = json.Unmarshal(b, &potential)
	if err != nil {
		return errors.Wrap(err, "contact: map stage failed")
	}

	t, ok := potential["type"].(string)
	if !ok {
		return ErrMalfromedMsg{"contact: no type on message", nil}
	}

	if t != "contact" {
		return ErrWrongType{want: "contact", has: t}
	}

	newC := new(Contact)

	contact, ok := potential["contact"].(string)
	if !ok {
		return ErrMalfromedMsg{"contact: no string contact field on type:contact", potential}
	}

	newC.Contact, err = ParseFeedRef(contact)
	if err != nil {
		return errors.Wrap(err, "contact: map stage failed")
	}

	newC.Following, _ = potential["following"].(bool)
	newC.Blocking, _ = potential["blocking"].(bool)

	*c = *newC
	return nil
}

type About struct {
	Type        string   `json:"type"`
	About       *FeedRef `json:"about"`
	Name        string   `json:"name,omitempty"`
	Description string   `json:"description,omitempty"`
	Image       *BlobRef `json:"image,omitempty"`
}

func NewAboutName(who *FeedRef, name string) *About {
	return &About{
		Type:  "about",
		About: who,
		Name:  name,
	}
}

func NewAboutImage(who *FeedRef, img *BlobRef) *About {
	return &About{
		Type:  "about",
		About: who,
		Image: img,
	}
}

func (a *About) UnmarshalJSON(b []byte) error {
	var priv string
	err := json.Unmarshal(b, &priv)
	if err == nil {
		return ErrWrongType{want: "about", has: "private.box?"}
	}

	var potential map[string]interface{}
	err = json.Unmarshal(b, &potential)
	if err != nil {
		return errors.Wrap(err, "about: map stage failed")
	}

	t, ok := potential["type"].(string)
	if !ok {
		return ErrMalfromedMsg{"about: no type on message", nil}
	}

	if t != "about" {
		return ErrWrongType{want: "about", has: t}
	}

	newA := new(About)

	about, ok := potential["about"].(string)
	if !ok {
		return ErrMalfromedMsg{"about: no string about field on type:about", potential}
	}

	newA.About, err = ParseFeedRef(about)
	if err != nil {
		return errors.Wrap(err, "about: who?")
	}

	if newName, ok := potential["name"].(string); ok {
		newA.Name = newName
	}
	if newDesc, ok := potential["description"].(string); ok {
		newA.Description = newDesc
	}

	var newImgBlob string
	if img, ok := potential["image"].(string); ok {
		newImgBlob = img
	}
	if imgObj, ok := potential["image"].(map[string]interface{}); ok {
		lnk, ok := imgObj["link"].(string)
		if ok {
			newImgBlob = lnk
		}
	}
	if newImgBlob != "" {
		br, err := ParseBlobRef(newImgBlob)
		if err != nil {
			return errors.Wrapf(err, "about: invalid image: %q", newImgBlob)
		}
		newA.Image = br
	}

	*a = *newA
	return nil
}

type Typed struct {
	Value
	Content struct {
		Type string `json:"type"`
	} `json:"content"`
}

type ValuePost struct {
	Value
	Content Post `json:"content"`
}

type Post struct {
	Type     string      `json:"type"`
	Text     string      `json:"text"`
	Root     *MessageRef `json:"root,omitempty"`
	Branch   MessageRefs `json:"branch,omitempty"`
	Mentions []Mention   `json:"mentions,omitempty"`
}

type Mention struct {
	Link FeedRef `json:"link"`
	Name string  `json:"name"`
}

type ValueVote struct {
	Value
	Content Vote `json:"content"`
}

type Vote struct {
	Type string `json:"type"`
	Vote struct {
		Expression string      `json:"expression"`
		Link       *MessageRef `json:"link"`
		Value      int         `json:"value"`
	} `json:"vote"`
}

type KeyValueRaw struct {
	Key_      *MessageRef           `json:"key"`
	Value     Value                 `json:"value"`
	Timestamp encodedTime.Millisecs `json:"timestamp"`
}

type KeyValueAsMap struct {
	Key       *MessageRef           `json:"key"`
	Value     Value                 `json:"value"`
	Timestamp encodedTime.Millisecs `json:"timestamp"`
}

var _ Message = (*KeyValueRaw)(nil)

func (kvr KeyValueRaw) Seq() int64 {
	return kvr.Value.Sequence.Seq()
}

func (kvr KeyValueRaw) Key() *MessageRef {
	return kvr.Key_
}

func (kvr KeyValueRaw) Author() *FeedRef {
	return &kvr.Value.Author
}

func (kvr KeyValueRaw) Previous() *MessageRef {
	return kvr.Value.Previous
}

func (kvr KeyValueRaw) Claimed() time.Time {
	return time.Time(kvr.Value.Timestamp)
}

func (kvr KeyValueRaw) Received() time.Time {
	return time.Time(kvr.Timestamp)
}

func (kvr KeyValueRaw) ContentBytes() []byte {
	return kvr.Value.Content
}

func (kvr KeyValueRaw) ValueContent() *Value {
	return &kvr.Value
}

func (kvr KeyValueRaw) ValueContentJSON() json.RawMessage {
	jsonB, err := json.Marshal(kvr.ValueContent())
	if err != nil {
		panic(err.Error())
	}

	return jsonB
}
