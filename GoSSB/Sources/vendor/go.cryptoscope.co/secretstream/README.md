# secretstream [![Build Status](https://travis-ci.org/cryptoscope/secretstream.svg?branch=master)](https://travis-ci.org/cryptoscope/secretstream) [![GoDoc](https://godoc.org/go.cryptoscope.co/secretstream?status.svg)](https://godoc.org/go.cryptoscope.co/secretstream) [![Go Report Card](https://goreportcard.com/badge/go.cryptoscope.co/secretstream)](https://goreportcard.com/report/go.cryptoscope.co/secretstream) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A port of [secret-handshake](https://github.com/auditdrivencrypto/secret-handshake) to [Go](https://golang.org).

Provides an encrypted bidirectional stream using two [boxstream]s.
Uses [secret-handshake] to negotiate the keys and nonces.

[boxstream]: https://github.com/dominictarr/pull-box-stream
[secret-handshake]: https://github.com/auditdrivencrypto/secret-handshake


## Development

If you want to run the compatability tests against the nodejs implementation, run `npm ci && go test -tags interop_nodejs` on the `secrethandshake` and `boxstream` sub-packages.

