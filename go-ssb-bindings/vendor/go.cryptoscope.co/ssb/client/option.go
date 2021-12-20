package client

import (
	"context"
	"encoding/base64"
	"fmt"

	"go.mindeco.de/log"
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
			return fmt.Errorf("ssbClient: failed to decode secret-handshake appKey: %w", err)
		}
		if n := len(c.appKeyBytes); n != 32 {
			return fmt.Errorf("ssbClient: invalid length for appKey: %d", n)
		}
		return nil
	}
}
