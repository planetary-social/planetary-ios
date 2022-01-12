// SPDX-License-Identifier: MIT

package message

import (
	"strings"

	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb"
)

type WhoamiReply struct {
	ID *ssb.FeedRef `json:"id"`
}

func NewCreateHistArgsFromMap(argMap map[string]interface{}) (*CreateHistArgs, error) {

	// could reflect over qrys fiields but meh - compiler knows better
	var qry CreateHistArgs
	for k, v := range argMap {
		switch k = strings.ToLower(k); k {
		case "live", "keys", "values", "reverse", "asjson":
			b, ok := v.(bool)
			if !ok {
				return nil, errors.Errorf("ssb/message: not a bool for %s", k)
			}
			switch k {
			case "live":
				qry.Live = b
			case "keys":
				qry.Keys = b
			case "values":
				qry.Values = b
			case "reverse":
				qry.Reverse = b
			case "asjson":
				qry.AsJSON = b
			}

		case "type":
			fallthrough
		case "id":
			val, ok := v.(string)
			if !ok {
				return nil, errors.Errorf("ssb/message: not string (but %T) for %s", v, k)
			}
			switch k {
			case "id":
				var err error
				qry.ID, err = ssb.ParseFeedRef(val)
				if err != nil {
					return nil, errors.Wrapf(err, "ssb/message: not a feed ref")
				}

				// TODO:
				// case "type":
				// qry.Type = val
			}
		case "seq", "limit":
			n, ok := v.(float64)
			if !ok {
				return nil, errors.Errorf("ssb/message: not a float64(%T) for %s", v, k)
			}
			switch k {
			case "seq":
				qry.Seq = int64(n)
			case "limit":
				qry.Limit = int64(n)
			}
		}
	}

	if qry.Limit == 0 {
		qry.Limit = -1
	}

	return &qry, nil
}

type CommonArgs struct {
	Keys   bool `json:"keys"` // can't omit this falsy value, the JS-stack stack assumes true if it's not there
	Values bool `json:"values,omitempty"`
	Live   bool `json:"live,omitempty"`

	// this field is used to tell muxrpc into wich type the messages should be marshaled into.
	// for instance, it could be json.RawMessage or a map or a struct
	// TODO: find a nice way to have a default here
	MarshalType interface{} `json:"-"`
}

type StreamArgs struct {
	Limit int64 `json:"limit,omitempty"`

	Reverse bool `json:"reverse,omitempty"`
}

// CreateHistArgs defines the query parameters for the createHistoryStream rpc call
type CreateHistArgs struct {
	CommonArgs
	StreamArgs

	ID  *ssb.FeedRef `json:"id,omitempty"`
	Seq int64        `json:"seq,omitempty"`

	AsJSON bool `json:"asJSON,omitempty"`
}

// CreateLogArgs defines the query parameters for the createLogStream rpc call
type CreateLogArgs struct {
	CommonArgs
	StreamArgs

	Seq int64 `json:"seq"`
}

// MessagesByTypeArgs defines the query parameters for the messagesByType rpc call
type MessagesByTypeArgs struct {
	CommonArgs
	Type string `json:"type"`
}

type TanglesArgs struct {
	CommonArgs
	StreamArgs
	Root ssb.MessageRef `json:"root"`
}
