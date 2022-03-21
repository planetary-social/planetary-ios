#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2021 The Go-SSB Authors
#
# SPDX-License-Identifier: MIT

set -x

dest=$1
test "$dest" != "" || {
    echo "dest: ${dest} not set"
    exit 1
}


sha256sum -c v2-sloop-m100000-a2000.tar.gz.shasum || {
    wget "https://github.com/ssb-ngi-pointer/ssb-fixtures/releases/download/2.3.0/v2-sloop-m100000-a2000.tar.gz"

    echo 'rerun me'
    exit 0
}


rm -r tmp
rm -r testrun

mkdir -p tmp/unpack
tar xf v2-sloop-m100000-a2000.tar.gz -C tmp/unpack

go run go.cryptoscope.co/ssb/cmd/ssb-offset-converter -if lfo tmp/unpack/flume/log.offset $dest