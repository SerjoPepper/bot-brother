promise = require 'bluebird'
redis = require 'redis'
create = require('./index').create

DEFAULT_PREFIX = 'BOT_SESSIONS'
DEFUALT_CONFIG = {host: '127.0.0.1', port: '6379'}

promise.promisifyAll(redis)

module.exports = (config, prefix = DEFAULT_PREFIX) -> (bot) ->
  config ||= DEFUALT_CONFIG
  client = config.client || redis.createClient(config)
  client.select(config.db) if config.db

  parseSession = (session) ->
    session && JSON.parse(session)

  create({

    save: (id, session) ->
      client.hsetAsync("#{prefix}:#{bot.id}", id, JSON.stringify(session))

    get: (id) ->
      client.hgetAsync("#{prefix}:#{bot.id}", id).then(parseSession)

    getMultiple: (ids) ->
      client.hmgetAsync(["#{prefix}:#{bot.id}"].concat(ids)).then (sessions) ->
        sessions.filter(Boolean).map(parseSession)

    getAll: ->
      client.hvalsAsync("#{prefix}:#{bot.id}").then (sessions) ->
        sessions.filter(Boolean).map(parseSession)

  })