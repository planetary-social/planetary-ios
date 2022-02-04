<!--
SPDX-FileCopyrightText: 2021 The go-metafeed Authors

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# go-metafeeds

This [Go](https://golang.org) module implements the [bendy butt specification](https://github.com/ssb-ngi-pointer/bendy-butt-spec/) to encode and verify feed entries in that format and offers utility functions for creating and verifiying signed content entries as required by the [meta feed spec](https://github.com/ssb-ngi-pointer/ssb-meta-feed-spec).

This repository also offers JSON test vectors to assist in testing implementations in other languages.

## Usage

See the [![Go Reference](https://pkg.go.dev/badge/github.com/ssb-ngi-pointer/go-metafeed.svg)](https://pkg.go.dev/github.com/ssb-ngi-pointer/go-metafeed) for an exhaustive list of all the APIs this package offers. 

The `metamngmt` Package offers helper types and functions to create the necessary types to manage the subfeeds of a metafeed.

To get the complete picture, read `internal/vectors/gen_good_test.go` which creates the `testvector-metafeed-managment.json` and goes through all the steps of creating feed entries and signing subfeeds.

### Generating Vectors
Test vector generation is facilitated through [Go's testing system](https://godocs.io/testing).

To regenerate the vectors (e.g. after having changed vector generation `./internal/vectors`),
run the `go test` command:

```
cd internal/vectors/
go test
```

_(Alternatively: stand in the root of the repo and run `go test ./internal/vectors/`)_

## License

The code is licenses under MIT.

The test vectors are licensed under Creative Commons Attribution Share Alike 4.0.

[![REUSE status](https://api.reuse.software/badge/github.com/ssb-ngi-pointer/go-metafeed)](https://api.reuse.software/info/github.com/ssb-ngi-pointer/go-metafeed)

