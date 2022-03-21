// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

/*
    this helper works together with the TestCompat* func()s in signature_test.go
    
    we use tape to make the process exit with an non-zero code if anything is wrong

    it's job is verify and create signatures over data that is configured over environment variables:

    * testaction: which test to run
    * testobj: base64 encoded json object (b64 just to make newline handling easier)
    * testseed: the seed data to create the keypair
    * testpublic: the expected public key (preliminary sanity check that keypair seeding works)
    * testhmackey: used by HMAC_* as the secret
    
    the sign actions output the generated signature to stdout
*/
var tape = require('tape')
var ssbKeys = require('ssb-keys')

tape.createStream().pipe(process.stderr);

tape("got seed and action", (t) => {
    let testobj = JSON.parse(Buffer.from(process.env.testobj, 'base64'))
    t.ok(testobj, 'got test object')
    
    let action = process.env.testaction
    t.notEqual(['sign', 'verify', 'hmac_sign', 'hmac_verify'].indexOf(action), -1, 'is valid action')


    let seed = Buffer.from(process.env.testseed, 'base64')
    t.equal(seed.length,32, 'got test seed for key')
    
    var keys = ssbKeys.generate('ed25519', seed)
    t.equal(keys.id, process.env.testpublic, 'wrong pubkey for testseed')

    if (action == 'sign')
    tape("sign", (t) => {
        var sig = ssbKeys.signObj(keys.private, testobj)
        t.ok(sig.signature)
        console.log(sig.signature)
        t.end()
    })
    
    if (action == 'verify')
    tape("verify", (t) => {
        t.ok(testobj.signature, "has signature")
        t.ok(ssbKeys.verifyObj({public:keys.public}, testobj), "verify")
        t.end()
    })
    
    var hmacKey = {'invalid': true}
    if (action.lastIndexOf('hmac_', 0) === 0) {
        hmacKey = Buffer.from(process.env.testhmackey, 'base64')
        t.equal(hmacKey.length, 32, 'got HMAC key')
    }

    if (action == 'hmac_sign')
    tape("sign with HMAC", (t) => {
        var sig = ssbKeys.signObj(keys.private, hmacKey, testobj)
        t.ok(sig.signature)
        console.log(sig.signature)
        t.end()
    })

    if (action == 'hmac_verify')
    tape("verify with HMAC", (t) => {
        t.ok(testobj.signature, "has signature")
        t.ok(ssbKeys.verifyObj({public:keys.public}, hmacKey, testobj), "verify")
        t.end()
    })

    t.end()
})
