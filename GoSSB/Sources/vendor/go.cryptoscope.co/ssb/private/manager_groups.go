package private

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"

	"go.cryptoscope.co/margaret"

	"go.cryptoscope.co/ssb/private/box2"
	"go.cryptoscope.co/ssb/private/keys"
	refs "go.mindeco.de/ssb-refs"
	"go.mindeco.de/ssb-refs/tfk"
)

type groupInit struct {
	Type string `json:"type"`
	Name string `json:"name"`

	Tangles refs.Tangles `json:"tangles"`
}

var emptyMsgRef = refs.MessageRef{}

// Create returns cloaked id and public root of a new group
func (mgr *Manager) Create(name string) (refs.MessageRef, refs.MessageRef, error) {
	// roll new key
	var groupKey keys.Recipient
	groupKey.Scheme = keys.SchemeLargeSymmetricGroup
	groupKey.Key = make([]byte, 32) // TODO: key size const
	_, err := rand.Read(groupKey.Key)
	if err != nil {
		return emptyMsgRef, emptyMsgRef, err
	}

	// prepare init content
	var gi groupInit
	gi.Type = "group/init"
	gi.Name = name
	gi.Tangles = make(refs.Tangles)
	gi.Tangles["group"] = refs.TanglePoint{}   // empty/root
	gi.Tangles["members"] = refs.TanglePoint{} // empty/root

	jsonContent, err := json.Marshal(gi)
	if err != nil {
		return emptyMsgRef, emptyMsgRef, err
	}

	// encrypt the group/init message
	publicRoot, err := mgr.encryptAndPublish(jsonContent, keys.Recipients{groupKey})
	if err != nil {
		return emptyMsgRef, emptyMsgRef, err
	}

	groupKey.Metadata.GroupRoot = publicRoot

	cloakedID, err := mgr.deriveCloakedAndStoreNewKey(groupKey)
	if err != nil {
		return emptyMsgRef, emptyMsgRef, err
	}

	return cloakedID, publicRoot, nil
}

// Join is called with a groupKey and the tangle root for the group.
// It adds the key to the keystore so that messages to this group can be decrypted.
// It returns the cloaked message reference or an error.
func (mgr *Manager) Join(groupKey []byte, root refs.MessageRef) (refs.MessageRef, error) {
	var r keys.Recipient
	r.Scheme = keys.SchemeLargeSymmetricGroup
	r.Key = make([]byte, 32) // TODO: key size const

	if n := len(groupKey); n != 32 {
		return emptyMsgRef, fmt.Errorf("groups/join: passed key length (%d)", n)
	}
	copy(r.Key, groupKey)

	r.Metadata.GroupRoot = root

	cloakedID, err := mgr.deriveCloakedAndStoreNewKey(r)
	if err != nil {
		return emptyMsgRef, err
	}

	return cloakedID, nil
}

func (mgr *Manager) deriveCloakedAndStoreNewKey(k keys.Recipient) (refs.MessageRef, error) {

	if k.Key == nil {
		return emptyMsgRef, fmt.Errorf("deriveCloaked: nil recipient key")
	}

	// TODO: might find a way without this 2nd roundtrip of getting the message.
	initMsg, err := mgr.receiveByRef.Get(k.Metadata.GroupRoot)
	if err != nil {
		return emptyMsgRef, err
	}

	ctxt, err := box2.GetCiphertextFromMessage(initMsg)
	if err != nil {
		return emptyMsgRef, err
	}

	var prev refs.MessageRef
	if initPrev := initMsg.Previous(); initPrev != nil {
		prev = *initPrev
	} else {
		prev, err = refs.NewMessageRefFromBytes(bytes.Repeat([]byte{0}, 32), refs.RefAlgoMessageSSB1)
		if err != nil {
			return emptyMsgRef, err
		}
	}

	readKey, err := box2.NewBoxer(mgr.rand).GetReadKey(ctxt, initMsg.Author(), prev, keys.Recipients{k})
	if err != nil {
		return emptyMsgRef, err
	}

	rootAsTFK, err := tfk.Encode(k.Metadata.GroupRoot)
	if err != nil {
		return emptyMsgRef, err
	}

	var cloakedID = make([]byte, 32)
	err = box2.DeriveTo(cloakedID, readKey, []byte("cloaked_msg_id"), rootAsTFK)
	if err != nil {
		return emptyMsgRef, err
	}

	err = mgr.keymgr.AddKey(sortAndConcat(mgr.author.ID().PubKey(), mgr.author.ID().PubKey()), k)
	if err != nil {
		return emptyMsgRef, err
	}

	cloakedRef, err := refs.NewMessageRefFromBytes(cloakedID, refs.RefAlgoCloakedGroup)
	if err != nil {
		return emptyMsgRef, err
	}

	// store group key as tfk from floakedRef
	cloakedTfk, err := tfk.Encode(cloakedRef)
	if err != nil {
		return emptyMsgRef, err
	}

	err = mgr.keymgr.AddKey(cloakedTfk, k)
	if err != nil {
		return emptyMsgRef, err
	}

	return cloakedRef, nil
}

// GroupAddMember is a JSON serialization helper.
// See https://github.com/ssbc/private-group-spec/tree/master/group/add-member for more.
type GroupAddMember struct {
	Type string `json:"type"`
	Text string `json:"text"`

	Version string `json:"version"`

	GroupKey keys.Base64String `json:"groupKey"`
	Root     refs.MessageRef   `json:"root"` // initial message

	Recps []string `json:"recps"`

	Tangles refs.Tangles `json:"tangles"`
}

// AddMember creates, encrypts and publishes a GroupAddMember message.
func (mgr *Manager) AddMember(groupID refs.MessageRef, r refs.FeedRef, welcome string) (refs.MessageRef, error) {
	if groupID.Algo() != refs.RefAlgoCloakedGroup {
		return refs.MessageRef{}, fmt.Errorf("not a group")
	}

	gskey, err := mgr.keymgr.GetKeysForMessage(keys.SchemeLargeSymmetricGroup, groupID)
	if err != nil {
		return refs.MessageRef{}, fmt.Errorf("failed to get key for group: %w", err)
	}

	if n := len(gskey); n != 1 {
		return refs.MessageRef{}, fmt.Errorf("inconsistent group-key count: %d", n)
	}

	sk, err := mgr.GetOrDeriveKeyFor(r)
	if err != nil {
		return refs.MessageRef{}, fmt.Errorf("failed to derive key for feed: %w", err)
	}
	gskey = append(gskey, sk...)

	// prepare init content
	var ga GroupAddMember
	ga.Type = "group/add-member"
	ga.Version = "v1"
	ga.Text = welcome

	ga.GroupKey = keys.Base64String(gskey[0].Key)
	groupRoot := gskey[0].Metadata.GroupRoot
	ga.Root = groupRoot

	ga.Recps = []string{groupID.Ref(), r.Ref()}

	ga.Tangles = make(refs.Tangles)

	ga.Tangles["group"] = mgr.getTangleState(groupRoot, "group")
	ga.Tangles["members"] = mgr.getTangleState(groupRoot, "members")

	jsonContent, err := json.Marshal(ga)
	if err != nil {
		return refs.MessageRef{}, err
	}

	return mgr.encryptAndPublish(jsonContent, gskey)
}

// PublishTo encrypts and publishes a json blob as content to a group.
func (mgr *Manager) PublishTo(groupID refs.MessageRef, content []byte) (refs.MessageRef, error) {
	if groupID.Algo() != refs.RefAlgoCloakedGroup {
		return refs.MessageRef{}, fmt.Errorf("not a group")
	}
	rs, err := mgr.keymgr.GetKeysForMessage(keys.SchemeLargeSymmetricGroup, groupID)
	if err != nil {
		return refs.MessageRef{}, err
	}
	if nr := len(rs); nr != 1 {
		return refs.MessageRef{}, fmt.Errorf("expected 1 key for group, got %d", nr)
	}
	r := rs[0]

	// assign group tangle
	var decodedContent map[string]interface{}
	err = json.Unmarshal(content, &decodedContent)
	if err != nil {
		return refs.MessageRef{}, err
	}

	var groupState = map[string]refs.TanglePoint{}
	groupState["group"] = mgr.getTangleState(r.Metadata.GroupRoot, "group")
	decodedContent["tangles"] = groupState

	updatedContent, err := json.Marshal(decodedContent)
	if err != nil {
		return refs.MessageRef{}, err
	}

	return mgr.encryptAndPublish(updatedContent, rs)
}

// PublishPostTo publishes a new post to a group.
// TODO: reply root?
func (mgr *Manager) PublishPostTo(groupID refs.MessageRef, text string) (refs.MessageRef, error) {
	if groupID.Algo() != refs.RefAlgoCloakedGroup {
		return refs.MessageRef{}, fmt.Errorf("publishToGroup: not a group")
	}
	rs, err := mgr.keymgr.GetKeysForMessage(keys.SchemeLargeSymmetricGroup, groupID)
	if err != nil {
		return refs.MessageRef{}, fmt.Errorf("publishToGroup: failed to get key for message: %w", err)
	}

	// TODO: make sure the skeymgr makes these unique
	if nr := len(rs); nr < 1 {
		return refs.MessageRef{}, fmt.Errorf("expected 1 key for group, got %d", nr)
	}
	r := rs[0]

	var p refs.Post
	p.Type = "post"
	p.Text = text
	p.Recps = refs.MessageRefs{groupID}
	p.Tangles = make(refs.Tangles)

	p.Tangles["group"] = mgr.getTangleState(r.Metadata.GroupRoot, "group")

	content, err := json.Marshal(p)
	if err != nil {
		return refs.MessageRef{}, fmt.Errorf("publishToGroup: failed to encode post data: %w", err)
	}
	return mgr.encryptAndPublish(content, rs)
}

// utils

// TODO: protect against race of changing previous
func (mgr *Manager) encryptAndPublish(c []byte, recps keys.Recipients) (refs.MessageRef, error) {
	if !json.Valid(c) {
		return refs.MessageRef{}, fmt.Errorf("box2 manager: passed content is not valid JSON")
	}

	prev, err := mgr.getPrevious()
	if err != nil {
		return refs.MessageRef{}, err
	}

	// now create the ciphertext
	bxr := box2.NewBoxer(mgr.rand)

	// TODO: maybe fix prev:null case by passing an empty ref instead of nil
	ciphertext, err := bxr.Encrypt(c, mgr.author.ID(), prev, recps)
	if err != nil {
		return refs.MessageRef{}, err
	}

	return mgr.publishCiphertext(ciphertext)
}

func (mgr *Manager) getPrevious() (refs.MessageRef, error) {
	// get current sequence
	currSeq := mgr.publog.Seq()

	// if first message
	if currSeq == margaret.SeqEmpty {
		return refs.MessageRef{}, nil
	}

	// else get the message
	msgV, err := mgr.publog.Get(currSeq)
	if err != nil {
		return refs.MessageRef{}, err
	}
	msg := msgV.(refs.Message)

	// and its key is the previous for that message
	prev := msg.Key()
	return prev, nil
}

func (mgr *Manager) publishCiphertext(ctxt []byte) (refs.MessageRef, error) {
	// TODO: format check for gabbygrove
	content := base64.StdEncoding.EncodeToString(ctxt) + ".box2"

	r, err := mgr.publog.Publish(content)
	if err != nil {
		return refs.MessageRef{}, err
	}
	return r, nil
}
