<!--
SPDX-FileCopyrightText: 2021 The Go-SSB Authors

SPDX-License-Identifier: MIT
-->

# Repo layout

TODO properly spec this

An example repo layout:
```
.ssb-go
.ssb-go/manifest.json
.ssb-go/secret
.ssb-go/log/data
.ssb-go/log/jrnl
.ssb-go/log/ofst

.ssb-go/blobs
.ssb-go/blobs/tmp
.ssb-go/blobs/hashAlgos.../blobDirs.../blobs...

.ssb-go/indexes/
.ssb-go/indexes/contacts/db
.ssb-go/indexes/contacts/db/badgerFiles...

.ssb-go/sublogs/
.ssb-go/sublogs/userFeeds/state.json
.ssb-go/sublogs/userFeeds/db
.ssb-go/sublogs/userFeeds/db/badgerFiles...

.ssb-go/plugins/pluginNames.../<plugin workspace, here can be anything>
```
