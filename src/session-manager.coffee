promise = require 'bluebird'
jsonfn = require 'json-fn'

PREFIX = 'BOT_SESSIONS'

promise.promisifyAll(redis)

class SessionManager

  constructor: (@bot) ->

  get: (id) ->
    @bot.redis.hgetAsync("#{PREFIX}:#{@bot.id}", id).then (session) ->
      session && jsonfn.parse(session)

  save: (id, session) ->
    @bot.redis.hsetAsync("#{PREFIX}:#{@bot.id}", id, jsonfn.stringify(session))

  getMultiple: (ids) ->
    @bot.redis.hmgetAsync(["#{PREFIX}:#{@bot.id}"].concat(ids)).then (sessions) ->
      sessions.filter(Boolean).map (session) -> jsonfn.parse(session)

  getAll: ->
    @bot.redis.hvalsAsync("#{PREFIX}:#{@bot.id}").then (sessions) ->
      sessions.filter(Boolean).map (session) -> jsonfn.parse(session)


module.exports = SessionManager