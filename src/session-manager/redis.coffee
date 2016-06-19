promise = require 'bluebird'
redis = require 'redis'
create = require('./index').create

DEFAULT_PREFIX = 'BOT_SESSIONS'
DEFUALT_CONFIG = {host: '127.0.0.1', port: '6379'}

promise.promisifyAll(redis)

module.exports = (config, prefix = PREFIX) -> (bot) ->
  client = config.client || redis.createClient(config)
  client.select(config.db) if config.db
  parseSession = (session) ->
    session && JSON.parse(session)

  create({

    save: (id, session) ->
      client.hsetAsync("#{prefix}:#{bot.id}", id, JSON.stringify(session))

    get: (id) ->
      @bot.redis.hgetAsync("#{prefix}:#{bot.id}", id).then(parseSession)

    getMultiple: (ids) ->
      @bot.redis.hmgetAsync(["#{prefix}:#{bot.id}"].concat(ids)).then (sessions) ->
        sessions.filter(Boolean).map(parseSession)

    getAll: ->
      @bot.redis.hvalsAsync("#{prefix}:#{bot.id}").then (sessions) ->
        sessions.filter(Boolean).map(parseSession)

  })