Promise = require 'bluebird'
co = require 'co'
###
# limit messages to 10
promiseRateLimit(30) ->
  ctx.sendMessage('Hello')
###
exports.rateLimiter = (rps = 30) ->
  fifo = []

  counter = 0
  interval = setInterval(
    ->
      counter = 0
      execNext()
    1000
  )

  execNext = ->
    if fifo.length && counter < rps
      {resolve, reject, handler} = fifo.pop()
      co(handler())
        .then(resolve, reject)
        .then(execNext, execNext)
      counter++
      execNext()

  limiter = (handler) ->
    promise = new Promise((resolve, reject) ->
      fifo.unshift({handler, resolve, reject})
    )
    execNext()
    promise

  limiter.destroy = ->
    reject(new Error('Destroy in rateLimiter')) for {reject} in fifo
    clearInterval(interval)

  limiter
