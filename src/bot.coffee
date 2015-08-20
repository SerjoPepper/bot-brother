Chat = require './chat'
Command = require './command'
CommandHandler = require './command-handler'
SessionManager = require './session-manager'
constants = require './constants'
mixins = require './mixins'
_ = require 'lodash'
Api = require 'node-telegram-bot-api'

class Bot

  constructor: (config) ->
    @config = config
    @config.redis ||= {}
    @sessionManager = @config.sessionManager || new SessionManager()
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
        @_handleMessage(msg)


  _handleMessage: (message) ->
    userId = message.from.id
    @sessionManager.get(userId).then (session) =>
      handler = new CommandHandler(message: message, bot: @, session: session)
      promise.try =>
        handler.handle()
      .then =>
        @sessionManager.save(userId, handler.session)


  # Returns middlewares for handling
  # @param {String} commandName the command name
  # @param {Object} params params
  # @option params {Boolean} includeParents include or not parent commands
  # @return {Object} middlewares structured by types
  getCommandsChain: (commandName, params = {}) ->
    return [] unless commandName
    commands = @commands
    .filter (command) ->
      command.name is commandName or
        _.isRegExp(command.name) and command.name.test(commandName) or
        params.includeParents && _.isString(command.name) && commandName.indexOf(command.name + '_') is 0
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
  getMiddlewaresChain: (commandsChain) ->
    commands = commandsChain.concat([@]) # adding bot middlewares
    middlewares = {}
    constants.STAGES.forEach (stage) =>
      commands.forEach (command) ->
        middlewares[stage.name] ||= []
        _commandMiddlewares = command.getMiddlewares(stage)
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
    @commands.push(new Command(_.extend({}, bot: @, options)))


  contextFromSession: (session) ->
    promise.try =>
      handler = new CommandHandler(bot: @, session: session, isSynthetic: true)
      handler.context


  # find chat by id
  withContext: (userId, cb) ->
    @sessionManager.get(userId).then (session) =>
      @contextFromSession(session).then (context) =>
        promise.try => cb(context)
      .then =>
        @sessionManager.save(userId, session)

  # find chats by ids
  withContexts: (ids, cb) ->
    @sessionManager.getMultiple(ids).map (session) =>
      @contextFromSession(session).then (context) =>
        promise.try => cb(context)
      .then =>
        @sessionManager.save(session.meta.userId, session)


  # provide all chats
  withAllContexts: (handler) ->
    @sessionManager.getAll().map (session) =>
      @contextFromSession(session).then (context) =>
        promise.try => cb(context)
      .then =>
        @sessionManager.save(session.meta.userId, session)

_.extend(Bot::, mixins)

module.exports = (config) -> new Bot(config)
module.exports.middlewares = middlewares