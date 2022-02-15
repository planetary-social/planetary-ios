package client

import (
	"context"
	"encoding/base64"

	"github.com/go-kit/kit/log"
	"github.com/pkg/errors"
)

type Option func(*Client) error

func WithContext(ctx context.Context) Option {
	return func(c *Client) error {
		c.rootCtx = ctx
		return nil
	}
}

func WithLogger(l log.Logger) Option {
	return func(c *Client) error {
		c.logger = l
		return nil
	}
}

func WithSHSAppKey(appKey string) Option {
	return func(c *Client) error {
		var err error
		c.appKeyBytes, err = base64.StdEncoding.DecodeString(appKey)
		if err != nil {
			return errors.Wrap(err, "ssbClient: failed to decode secret-handshake appKey")
		}
		if n := len(c.appKeyBytes); n != 32 {
			return errors.Errorf("ssbClient: invalid length for appKey: %d", n)
		}
		return nil
	}
}
