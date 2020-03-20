// SPDX-License-Identifier: MIT

package sbot

import (
	"net"
	"os"
	"sort"
	"time"

	"github.com/dustin/go-humanize"
	"github.com/pkg/errors"
	"go.cryptoscope.co/margaret"
	"go.cryptoscope.co/netwrap"
	"go.cryptoscope.co/ssb"
	multiserver "go.mindeco.de/ssb-multiserver"
)

func (sbot *Sbot) Status() (ssb.Status, error) {
	v, err := sbot.RootLog.Seq().Value()
	if err != nil {
		return ssb.Status{}, errors.Wrap(err, "failed to get root log sequence")
	}

	s := ssb.Status{
		PID:   os.Getpid(),
		Root:  margaret.BaseSeq(v.(margaret.Seq).Seq()),
		Blobs: sbot.WantManager.AllWants(),
	}

	edps := sbot.Network.GetAllEndpoints()

	sort.Sort(byConnTime(edps))

	for _, es := range edps {
		var ms multiserver.NetAddress
		ms.Ref = es.ID
		if tcpAddr, ok := netwrap.GetAddr(es.Addr, "tcp").(*net.TCPAddr); ok {
			ms.Addr = *tcpAddr
		}
		s.Peers = append(s.Peers, ssb.PeerStatus{
			Addr:  ms.String(),
			Since: humanize.Time(time.Now().Add(-es.Since)),
		})
	}
	return s, nil
}

type byConnTime []ssb.EndpointStat

func (bct byConnTime) Len() int {
	return len(bct)
}

func (bct byConnTime) Less(i int, j int) bool {
	return bct[i].Since < bct[j].Since
}

func (bct byConnTime) Swap(i int, j int) {
	bct[i], bct[j] = bct[j], bct[i]
}
