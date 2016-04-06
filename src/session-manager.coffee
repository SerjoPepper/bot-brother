promise = require 'bluebird'
jsonfn = require 'json-fn'
redis = require 'redis'

PREFIX = 'BOT_SESSIONS'
parseSession = (session, id) ->
  if session then jsonfn.parse(session) else {meta: chat: id: id}

promise.promisifyAll(redis)

class SessionManager

  constructor: (@bot) ->

  get: (id) ->
    @bot.redis.hgetAsync("#{PREFIX}:#{@bot.id}", id).then (session) ->
      session = parseSession(session, id)

  save: (id, session) ->
    @bot.redis.hsetAsync("#{PREFIX}:#{@bot.id}", id, jsonfn.stringify(session))

  getMultiple: (ids) ->
    @bot.redis.hmgetAsync(["#{PREFIX}:#{@bot.id}"].concat(ids)).then (sessions) ->
      sessions.filter(Boolean).map (session) -> parseSession(session)

  getAll: ->
    @bot.redis.hvalsAsync("#{PREFIX}:#{@bot.id}").then (sessions) ->
      sessions.filter(Boolean).map (session) -> parseSession(session)


module.exports = SessionManager