// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// creates a testdata.zip with two files per message on a feed
// $seq.encoded contains the bytes of the message using ssb-feed/utils impl
// $seq.orig contains the json stringifyed full message (containing .key and the msg under .value) for testing purposes

var hash = require('ssb-keys').hash
var encode = require('ssb-feed/util').encode
var pull = require('pull-stream')
var pullCatch = require('pull-catch')
var ssbClient = require('ssb-client')
var AdmZip = require('adm-zip'); // Had to apply https://github.com/cthackers/adm-zip/pull/217 - TODO: update package.json once it is merged
var zip = new AdmZip();

var feedID = "@p13zSAiOpguI9nsawkGijsnMfWmFd5rlUNpzekEE+vI=.ed25519"
if (process.argv.length == 3) {
  feedID = process.argv[2]
}
console.log('using id: ', feedID)

ssbClient( (err, sbot) => {
  if (err) throw err
  var i = 0
  pull(
    sbot.createHistoryStream({id:feedID, live:false}),
    pullCatch((err) => {
      if (err) throw err 
    }),
    pull.drain((msg) => {
	  var copy = {...msg.value}
	  delete(copy.signature)
      const e = encode(copy)
      const vInput = encode(msg.value)
      const vInputHash = "%"+hash(vInput)
      if (vInputHash !== msg.key) {
        throw new Error("key missmatch: " + msg.key + ":" + vInputHash)
      }
      zip.addFile(`${pad(msg.value.sequence,5)}.input`, vInput); // this gets hashed! but it's not valid json.... >> new Buffer(vInput, "binary"));
      zip.addFile(`${pad(msg.value.sequence,5)}.noSig`, e);
      zip.addFile(`${pad(msg.value.sequence,5)}.full`, JSON.stringify(msg)); // with .key, etc
      i++
    },() => { // done
      sbot.close()
      zip.writeZip("testdata.zip");
      console.log('done. wrote ', i, ' messages')
    })
  )
})

function pad(n, width, z) {
  z = z || '0';
  n = n + '';
  return n.length >= width ? n : new Array(width - n.length + 1).join(z) + n;
}

