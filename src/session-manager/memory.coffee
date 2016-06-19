promise = require 'bluebird'
fs = promise.promisifyAll(require('fs'))
create = require('./index').create
path = require 'path'
mkdirp = require 'mkdirp'

module.exports = (config = {}) -> (bot) ->
  dir = if config.dir
    path.resolve(process.cwd(), config.dir)
  else
    path.resolve(__dirname, '../../__storage')
  mkdirp.sync(dir)

  parseSession = (session) ->
    session && JSON.parse(session)

  fileName = (id) ->
    path.join(dir, "#{bot.id}.#{id}.json")

  create({

    save: (id, session) ->
      fs.writeFileAsync(fileName(id), JSON.stringify(session))

    get: (id) ->
      fs.statAsync(fileName(id)).then (exists) ->
        if exists
          fs.readFileAsync(fileName(id)).then(parseSession)
        else
          null
      .catch -> null

    getMultiple: (ids) ->
      promise.resolve(ids).map (id) => @get(id)

    getAll: ->
      # TODO

  })
