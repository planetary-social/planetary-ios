// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package sbot

import (
	"fmt"

	"go.cryptoscope.co/ssb/message"
	"go.cryptoscope.co/ssb/repo"
	refs "go.mindeco.de/ssb-refs"
)

func (sbot *Sbot) PublishAs(nick string, val interface{}) (refs.Message, error) {
	r := repo.New(sbot.repoPath)

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

	pl, err := message.OpenPublishLog(sbot.ReceiveLog, sbot.Users, kp, pubopts...)
	if err != nil {
		return nil, fmt.Errorf("publishAs: failed to create publish log: %w", err)
	}

	return pl.Publish(val)
}
