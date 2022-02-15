// SPDX-License-Identifier: MIT

var shs = require('secret-handshake')
var fs = require('fs')
var pull = require('pull-stream')
var toPull = require('stream-to-pull-stream')

function readKeyF (fname) {
  var tmpobj = JSON.parse(fs.readFileSync(fname).toString())
  return {
    publicKey: Buffer.from(tmpobj.publicKey, 'base64'),
    secretKey: Buffer.from(tmpobj.secretKey, 'base64')
  }
}

var alice = readKeyF('key.alice.json')
var bob = readKeyF('key.bob.json')

var createClient = shs.createClient(alice, Buffer.from('IhrX11txvFiVzm+NurzHLCqUUe3xZXkPfODnp7WlMpk=', 'base64'))

pull(
  toPull.source(process.stdin),
  createClient(bob.publicKey, function () { }),
  toPull.sink(process.stdout)
)
