// SPDX-License-Identifier: MIT

// a simple RPC server for client tests
var MRPC = require('muxrpc')
var pull = require('pull-stream')
var toPull = require('stream-to-pull-stream')
var pushable = require('pull-pushable')

var api = {
  manifest: 'sync',
  finalCall: 'async',
  version: 'sync',
  hello: 'async',
  callme: { // start calling back
    async: 'async',
    source: 'async',
    magic: 'async',
    withAbort: 'async'
  },
  object: 'async',
  stuff: 'source',
  magic: 'duplex',
  takeSome: 'source'
}

var bootstrap = (err, rpc, manifst) => {
  if (err) {
    console.error(err)
    throw err
  }
  // console.warn("got manifest:", manifst)
}

var server = MRPC(bootstrap, api)({
  manifest: () => {
    return api
  },
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
    source: function (n, cb) {
      pull(server.stuff(), pull.collect(function (err, vals) {
        if (err) {
          console.error(err)
          throw err
        }
        console.warn('callme:source:ok vals:', vals)

        if (vals.length !== n) throw new Error(`expected ${n} elements in source got ${vals.length}`)

        for (let i = 0; i < n; i++) {
          const el = vals[i];

          if (typeof el['a'] === 'undefined') throw new Error(`expected field 'a' in el ${i}`)
          if (el['a'] !== i) throw new Error(`expected vals[i]['a'] to be ${i} but got ${el['a']}`)
        }

        cb(null, 'call done')
      }))
    },
    async: (cb) => {
      server.hello(function (err, greet) {
        if (err) {
          console.error('callme:async:not okay')
          throw err
        } else {
          console.warn('callme:async:ok')
        }
        cb(err, 'call done')
      })
    },
    magic: (cb) => {
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
    },
    withAbort: (count, cb) => {
      pull(
        server.takeSome(),
        pull.take(count),
        pull.collect((err, val) => {
          if (err) return cb(err)
          if (val.length !== count) return cb(new Error('wrong item count:' + val.length))
          setTimeout(() => {
            // wait a moment (to make sure the other side stops)
            cb(null, 'thanks!')
          }, 1000)
        })
      )
    }
  },
  object: (cb) => {
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
