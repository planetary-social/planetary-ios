// SPDX-License-Identifier: MIT

package sbot

import (
	"github.com/pkg/errors"

	"go.cryptoscope.co/ssb"
	"go.cryptoscope.co/ssb/message"
	"go.cryptoscope.co/ssb/multilogs"
	"go.cryptoscope.co/ssb/repo"
)

func (sbot *Sbot) PublishAs(nick string, val interface{}) (*ssb.MessageRef, error) {
	r := repo.New(sbot.repoPath)

	uf, ok := sbot.GetMultiLog(multilogs.IndexNameFeeds)
	if !ok {
		return nil, errors.Errorf("requried idx not present: userFeeds")
	}

	kp, err := repo.LoadKeyPair(r, nick)
	if err != nil {
		return nil, err
	}

	var pubopts = []message.PublishOption{
		message.UseNowTimestamps(true),
	}
	if sbot.signHMACsecret != nil { // all feeds use the same settings right now
		pubopts = append(pubopts, message.SetHMACKey(sbot.signHMACsecret))
	}

	pl, err := message.OpenPublishLog(sbot.RootLog, uf, kp, pubopts...)
	if err != nil {
		return nil, errors.Wrap(err, "publishAs: failed to create publish log")
	}

	return pl.Publish(val)
}
