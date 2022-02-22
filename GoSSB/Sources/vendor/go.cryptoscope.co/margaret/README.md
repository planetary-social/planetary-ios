<!--
SPDX-FileCopyrightText: 2021 The margaret Authors

SPDX-License-Identifier: MIT
-->

# Margaret [![Go Reference](https://pkg.go.dev/badge/go.cryptoscope.co/margaret.svg)](https://pkg.go.dev/go.cryptoscope.co/margaret) ![[Github Actions Tests](https://github.com/cryptoscope/margaret/actions/workflows/go.yml)](https://github.com/cryptoscope/margaret/actions/workflows/go.yml/badge.svg) [![Go Report Card](https://goreportcard.com/badge/go.cryptoscope.co/margaret)](https://goreportcard.com/report/go.cryptoscope.co/margaret) [![REUSE status](https://api.reuse.software/badge/github.com/cryptoscope/margaret)](https://api.reuse.software/info/github.com/cryptoscope/margaret)

Margaret is [`go-ssb`](https://github.com/cryptoscope/ssb)'s [append-only](https://en.wikipedia.org/wiki/Append-only)
log\* provider, and greatly inspired by [flumedb](https://github.com/flumedb/flumedb). Compatible with Go 1.13+.

![margaret the log lady, 1989 edition](https://static.wikia.nocookie.net/twinpeaks/images/6/68/Logladyreplacement.jpg/revision/latest/scale-to-width-down/500?cb=20160906170235)

_the project name is inspired by Twin Peaks's character [Margaret](https://twinpeaks.fandom.com/wiki/Margaret_Lanterman) aka **the
log lady**_

Margaret has the following facilities:
* an append-only log interface `.Append(interface{})`, `.Get(int64)`
* [queries](https://godocs.io/go.cryptoscope.co/margaret#Query) `.Query(...QuerySpec)` for retrieving ranges based on sequence numbers e.g. `.Gt(int64)`, or limiting the amount of data returned `.Limit(int64)` 
* a variety of index mechanisms, both for categorizing log entries into buckets and for creating virtual logs (aka sublogs)

Margaret is one of a few key components that make the [go implementation of ssb](https://github.com/cryptoscope/ssb/) tick, for example:
* [`ssb/sbot`](https://github.com/cryptoscope/ssb/) uses margaret for storing each peer's data

### Log storage
Margaret outputs data according to the [`offset2`](https://godocs.io/go.cryptoscope.co/margaret/offset2) format, which is inspired by (but significantly differs from) [`flumelog-offset`](https://github.com/flumedb/flumelog-offset).

In brief: margaret stores the data of _all logs_ in the three following files:
* `data` stores the actual data (with a length-prefix before each entry)
* `ofst` indexes the starting locations for each data entry in `data`
* `jrnl` an integrity checking mechanism for all three files; a checksum of sorts, [more details](https://github.com/cryptoscope/margaret/blob/master/offset2/log.go#L215)

## More details
There are a few concepts that might be tough to digest for newcomers on first approach:

* multilogs, a kind of _tree_-based index, where each leaf is a margaret.Log
  * in other words: it creates virtual sublogs that map to entries in an offset log (see log storage above)
* `margaret/indexes` similar to leveldb indexes (arbitrary key-value stores)
* sublogs (and rxLog/receiveLog/offsetLog and its equivalence to offset.log)
* queries
* zeroing out, or replacing, written data

For more on these concepts, visit the [dev.scutttlebutt.nz](https://dev.scuttlebutt.nz/#/golang/) portal for in-depth explanations.


\* margaret is technically an append-_based_ log, as there is support for both zeroing out and
replacing items in the log after they have been written. Given the relative ubiquity of
append-only logs & their uses, it's easier to just say append-only log.
