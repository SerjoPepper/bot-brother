Command = require './command'
CommandHandler = require './command-handler'
sessionManager = require './session-manager'
constants = require './constants'
mixins = require './mixins'
utils = require './utils'
_ = require 'lodash'
redis = require 'redis'
promise = require 'bluebird'
Api = require 'node-telegram-bot-api'
co = require 'co'

###
Bot class

@property {String} key bot telegram key
@property {Number} id bot id
@property {Object} api telegram bot api
###
class Bot

  defaultConfig: {
    rps: 30
    sessionManager: sessionManager.memory()
  }

  ###
  @param {Object} config config
  @option config {String} key telegram bot token
  @option config {Object} [redis] redis config; see https://github.com/NodeRedis/node_redis#options-is-an-object-with-the-following-possible-properties
  @option config {Object} [redis.client] redis client
  @option config {Boolean} [polling] enable polling
  @option config {Object} [webHook] config for webhook
  @option config {String} [webHook.url] webook url
  @option config {String} [webHook.key] PEM private key to webHook server
  @option config {String} [webHook.cert] PEM certificate key to webHook server
  @option config {Number} [webHook.port] port for node.js server
  @option config {Boolean} [webHook.https] create secure node.js server
  @option config {Number} [rps=30] Maximum requests per second
  ###
  constructor: (config) ->
    @config = _.extend({}, @defaultConfig, config)
    @key = @config.key
    @id = Number(@key.match(/^\d+/)?[0])
    @commands = []
    @sessionManager = @config.sessionManager(@)
    @rateLimiter = utils.rateLimiter(@config.rps)
    @_initApi()

  ###
  Returns middlewares for handling.
  @param {String} commandName the command name
  @param {Object} [params] params
  @option params {Boolean} [includeBot] include bot middleware layer
  @return {Array} middlewares
  ###
  getCommandsChain: (commandName, params = {}) ->
    unless commandName
      return if params.includeBot then [@] else []
    commandName = commandName.toLowerCase() if _.isString(commandName)
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

  ###
  Return middlewares object.
  @param {Array} commands chain array
  @return {Object} middlewares object grouped by stages
  ###
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

  ###
  Return default command.
  @return {Command}
  ###
  getDefaultCommand: ->
    _.find(@commands, {isDefault: true})

  ###
  Register new command.
  @param {String|RegExp} name command name
  @param {Object} [options] options command options
  @option options {Boolean} [isDefault] is command default or not
  @option options {Boolean} [compliantKeyboard] handle answers not from keyboard
  @return {Command}
  ###
  command: (name, options = {}) ->
    command = new Command(name, _.extend({}, bot: @, options))
    @commands.push(command)
    command

  ###
  Inline query handler
  @param {Function} handler this function should return promise. first argument is {Context} ctx
  ###
  inlineQuery: (handler) ->
    @_inlineQueryHandler = handler

  ###
  Inline query handler
  @param {Function} handler this function should return promise. first argument is {Context} ctx
  ###
  chosenInlineResult: (handler) ->
    @_choseInlineResultHandler = handler

  ###
  @param {Object} session session object
  @return {Promise} return context
  ###
  contextFromSession: (session, prepareContext, params) ->
    handler = new CommandHandler(_.extend({bot: @, session: session, isSynthetic: true}, params))
    if prepareContext
      prepareContext(handler.context)
    promise.resolve(handler.handle()).then ->
      handler.context

  ###
  Invoke callback in context.
  @param {String} chatId
  @param {Funcion} handler
  @return {Promise}
  ###
  withContext: (chatId, prepareContext, handler) ->
    if !handler
      handler = prepareContext
      prepareContext = null
    @sessionManager.get(chatId).then (session) =>
      @contextFromSession(session, prepareContext).then (context) ->
        co(handler(context))
      # TODO save anytime
      .then =>
        @sessionManager.save(chatId, session)

  ###
  Same as withContext, but with multiple ids.
  @param {Array<String>} chatIds
  @param {Function} handler
  ###
  withContexts: (chatIds, handler) ->
    @sessionManager.getMultiple(chatIds).map (session) =>
      @contextFromSession(session).then (context) ->
        co(handler(context))
      .then =>
        @sessionManager.save(session.meta.sessionId, session)

  ###
  Same as withContexts, but with all chats.
  @param {Function} handler
  ###
  withAllContexts: (handler) ->
    @sessionManager.getAll().map (session) =>
      @contextFromSession(session).then (context) ->
        co(handler(context))
      .then =>
        @sessionManager.save(session.meta.sessionId, session)

  _onInlineQuery: (inlineQuery) =>
    @withContext(
      inlineQuery.from.id
      (context) -> context.setInlineQuery(inlineQuery)
      (context) => @_inlineQueryHandler(context)
    )

  _onChosenInlineResult: (chosenInlineResult) =>
    @withContext(
      chosenInlineResult.from.id
      (context) -> context.setChosenInlineResult(chosenInlineResult)
      (context) => @_choseInlineResultHandler(context)
    )

  _onMessage: (message) =>
    sessionId = @_provideSessionId(message)
    # 5 minutes to handle message
    if message.date * 1e3 + 60e3 * 5 > Date.now()
      @sessionManager.get(sessionId).then (session) =>
        if _.isEmpty(session)
          session = {meta: chat: id: sessionId}
        handler = new CommandHandler({message, session, bot: @})
        promise.resolve(handler.handle())
        .then =>
          @sessionManager.save(sessionId, handler.session)
    else
      throw new Error('Bad time: ' + JSON.stringify(message))

  _onCallbackQuery: (callbackQuery) =>
    {message} = callbackQuery
    sessionId = message && @_provideSessionId(message) || callbackQuery.from.id
    @sessionManager.get(sessionId).then (session) =>
      handler = new CommandHandler({callbackQuery, session, bot: @})
      promise.resolve(handler.handle())
      .then =>
        @sessionManager.save(sessionId, handler.session)

  _initApi: ->
    options = {}
    if @config.webHook
      options.webHook = @config.webHook
      if @config.secure is false
        delete options.webHook.key
    else
      options.polling = @config.polling
    @api = new Api(@key, options)
    @api.on 'message', @_onMessage
    @api.on 'inline_query', @_onInlineQuery
    @api.on 'chosen_inline_result', @_onChosenInlineResult
    @api.on 'callback_query', @_onCallbackQuery
    if @config.webHook
      @_setWebhook()
    else
      @_unsetWebhook()

  _unsetWebhook: ->
    @api.setWebHook('')

  _setWebhook: ->
    @api.setWebHook(@config.webHook.url, @config.webHook.cert).finally (res) ->
      console.log('webhook res:', res)

  _provideSessionId: (message) ->
    message.chat.id



_.extend(Bot::, mixins)

module.exports = (config) -> new Bot(config)
module.exports.middlewares = require('./middlewares')
module.exports.sessionManager = sessionManager
