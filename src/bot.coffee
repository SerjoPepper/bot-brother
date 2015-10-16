Command = require './command'
CommandHandler = require './command-handler'
SessionManager = require './session-manager'
constants = require './constants'
mixins = require './mixins'
_ = require 'lodash'
redis = require 'redis'
promise =require 'bluebird'
Api = require 'node-telegram-bot-api'

class Bot

  constructor: (config) ->
    @config = config
    @config.redis ||= {}
    @sessionManager = @config.sessionManager || new SessionManager(@)
    # bot api key
    @key = @config.key
    # bot id
    @id = @key.match(/^\d+/)?[0] || @key
    @redis = @config.redis.client || redis.createClient(@config.redis)
    @commands = []
    @_initApi()


  _initApi: ->
    @api?.destroy()
    @api = new Api(@key, @_isListen && {polling: @config.polling || true})
    if @_isListen
      @api.on 'message', (msg) =>
        @_handleMessage(msg).catch (err) ->
          console.error(err, err.stack)

  _provideSessionId: (message) ->
    if message.chat.id is message.from.id
      message.from.id
    else
      message.chat.id + ':' + message.from.id

  _handleMessage: (message) ->
    sessionId = @_provideSessionId(message)
    @sessionManager.get(sessionId).then (session) =>
      handler = new CommandHandler(message: message, bot: @, session: session)
      promise.try ->
        handler.handle()
      .then =>
        @sessionManager.save(sessionId, handler.session)


  # Returns middlewares for handling
  # @param {String} commandName the command name
  # @param {Object} params params
  # @return {Object} middlewares structured by types
  getCommandsChain: (commandName, params = {}) ->
    return [] unless commandName
    commands = @commands.slice().reverse()
    .filter (command) ->
      command.name is commandName or
        _.isRegExp(command.name) and command.name.test(commandName)
    .sort ({name: name1}, {name: name2}) ->
      [val1, val2] = [name1, name2].map (c) ->
        if _.isRegExp(c) then 0 else if c != commandName then -1 else 1
      if val1 < 0 && val2 < 0
        name2.length - name1.length
      else
        res = val2 - val1
    if params.includeBot
      commands.push(@)
    commands

  # Return middlewares object
  getMiddlewaresChains: (commandsChain) ->
    commands = commandsChain.concat([@]) # adding bot middlewares
    middlewares = {}
    constants.STAGES.forEach (stage) ->
      commands.forEach (command) ->
        middlewares[stage.name] ||= []
        _commandMiddlewares = command.getMiddlewares(stage.name)
        if stage.invert
          middlewares[stage.name] = _commandMiddlewares.concat(middlewares[stage.name])
        else
          middlewares[stage.name] = middlewares[stage.name].concat(_commandMiddlewares)
    middlewares


  getDefaultCommand: ->
    _.find(@commands, {isDefault: true})


  listenUpdates: ->
    @_isListen = true
    @_initApi()
    @


  stopListenUpdates: ->
    @_isListen = false
    @_initApi()
    @


  # register new command
  # name - regex or string
  command: (name, options = {}) ->
    command = new Command(name, _.extend({}, bot: @, options))
    @commands.push(command)
    command


  contextFromSession: (session) ->
    promise.try =>
      handler = new CommandHandler(bot: @, session: session, isSynthetic: true)
      handler.context


  # find chat by id
  withContext: (sessionId, cb) ->
    @sessionManager.get(sessionId).then (session) =>
      @contextFromSession(session).then (context) ->
        promise.try -> cb(context)
      .then =>
        @sessionManager.save(sessionId, session)

  # find chats by ids
  withContexts: (ids, cb) ->
    @sessionManager.getMultiple(ids).map (session) =>
      @contextFromSession(session).then (context) ->
        promise.try -> cb(context)
      .then =>
        @sessionManager.save(session.meta.sessionId, session)


  # provide all chats
  withAllContexts: (handler) ->
    @sessionManager.getAll().map (session) =>
      @contextFromSession(session).then (context) ->
        promise.try -> cb(context)
      .then =>
        @sessionManager.save(session.meta.sessionId, session)

_.extend(Bot::, mixins)

module.exports = (config) -> new Bot(config)
module.exports.middlewares = require('./middlewares')