# Gabby Grove for Go [![GoDoc](https://godoc.org/go.mindeco.de/ssb-gabbygrove?status.svg)](https://godoc.org/go.mindeco.de/ssb-gabbygrove)

This strives to be an easier implementation of https://spec.scuttlebutt.nz/feed/datamodel.html feeds.

Apart from making it easier to implement this (since the v8 specific JSON quirks go away), the most important improvement over the legacy format is _off-chain content_. This means only the hash of the content is signed and is committed on the chain.

Replication will stay very similar as well, by grouping metadata and content into the _transfer_ structure, omitting the content if it was delete by the remote.

It will also use the same cryptographic primitives ed25519 and sha256.

# Specification

See [draft-ssb-core-gabbygrove/00/](https://github.com/ssbc/ssb-spec-drafts/tree/d440fa4de4b772cc503ac2fc9bd0470a5836be62/drafts/draft-ssb-core-gabbygrove/00) at the https://github.com/ssbc/ssb-spec-drafts repository for a (hopefully) complete specification.

# License

MIT