// SPDX-License-Identifier: MIT

// a simple RPC server for client tests
var MRPC = require('muxrpc')
var pull = require('pull-stream')
var toPull = require('stream-to-pull-stream')
var pushable = require('pull-pushable')

var api = {
  finalCall: 'async',
  version: 'sync',
  hello: 'async',
  callme: { // start calling back
    async: 'async',
    source: 'async',
    magic: 'async'
  },
  object: 'async',
  stuff: 'source',
  magic: 'duplex'
}

var server = MRPC(api, api)({
  finalCall: function (delay, cb) {
    setTimeout(() => {
      cb(null, 'ty')

      server.close()
      setTimeout(() => {
        process.exit(0)
      }, 1000)
    }, delay)
  },
  version: function (some, args, i) {
    console.warn(arguments)
    if (some === 'wrong' && i === 42) {
      throw new Error('oh wow - sorry')
    }
    return 'some/version@1.2.3'
  },
  hello: function (name, name2, cb) {
    console.error('hello:ok')
    cb(null, 'hello, ' + name + ' and ' + name2 + '!')
  },
  callme: {
    source: function (cb) {
      pull(server.stuff(), pull.collect(function (err, vals) {
        if (err) {
          console.error(err)
          throw err
        }
        console.error('callme:source:ok vals:', vals)
        cb(err, 'call done')
      }))
    },
    async: function (cb) {
      server.hello(function (err, greet) {
        console.error('callme:async:ok')
        cb(err, 'call done')
      })
    },
    magic: function (cb) {
      console.error('callme:magic:starting')
      var p = pushable()
      var i = 0
      setInterval(() => {
        p.push(i)
        i++
        // if (i > 10) {
        //   p.end()
        // }
      }, 150)

      pull(
        p,
        server.magic(function (err) {
          console.error('duplex cb err:', err)
          cb(err, 'yey')
        }),
        pull.drain(function (value) {
          console.error('node got:', value)
          if (value && value.RXJS && value.RXJS === 9) {
            p.end()
          }
        })
      )
    }
  },
  object: function (cb) {
    console.error('object:ok')
    cb(null, { with: 'fields!' })
  },
  stuff: function () {
    console.error('stuff called')
    return pull.values([{ a: 1 }, { a: 2 }, { a: 3 }, { a: 4 }])
  },
  magic: function () {
    // normally, we'd use pull.values and pull.collect
    // however, pull.values sends 'end' onto the stream, which closes the muxrpc stream immediately
    // ...and we need the stream to stay open for the drain to collect
    var p = pushable()
    var i = 0
    setInterval(() => {
      p.push(i)
      i++
    }, 150)
    return {
      source: p,
      sink: pull.drain(function (value) {
        if (value === 'e') {
          // server.close()
          // process.exit(1)
          p.end()
        }
      })
    }
  }
})

var a = server.createStream()
pull(a, toPull.sink(process.stdout))
pull(toPull.source(process.stdin), a)
