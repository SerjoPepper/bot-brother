Command = require './command'
CommandHandler = require './command-handler'
SessionManager = require './session-manager'
constants = require './constants'
mixins = require './mixins'
_ = require 'lodash'
redis = require 'redis'
promise = require 'bluebird'
Api = require 'node-telegram-bot-api'


###
Bot class

@property {String} key bot telegram key
@property {Number} id bot id
@property {Object} api telegram bot api
###
class Bot

  ###
  @param {Object} config config
  @option config {String} key telegram bot token
  @option config {Object} [redis] redis config; see https://github.com/NodeRedis/node_redis#options-is-an-object-with-the-following-possible-properties
  @option config {Object} [redis.client] redis client
  @option config {Object} [webHook] config for webhook
  @option config {String} [webHook.url] webook url
  @option config {String} [webHook.key] PEM private key to webHook server
  @option config {String} [webHook.cert] PEM certificate key to webHook server
  @option config {Number} [webHook.port] port for node.js server
  @option config {Boolean} [webHook.https] create secure node.js server
  ###
  constructor: (config) ->
    @config = config
    @config.redis ||= {host: '127.0.0.1', port: '6379'}
    @sessionManager = @config.sessionManager || new SessionManager(@)
    @key = @config.key
    @id = Number(@key.match(/^\d+/)?[0])
    @redis = @config.redis.client || redis.createClient(@config.redis)
    @redis.select(@config.redis.db) if @config.redis.db
    @commands = []
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
      if params.includeBot
        return [@]
      else
        []
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
  @param {Object} session session object
  @return {Promise} return context
  ###
  contextFromSession: (session) ->
    promise.try =>
      handler = new CommandHandler(bot: @, session: session, isSynthetic: true)
      handler.handle().then ->
        handler.context


  ###
  Invoke callback in context.
  @param {String} chatId
  @param {Function} cb function that invoke with context parameter. Should return promise.
  @return {Promise}
  ###
  withContext: (chatId, cb) ->
    @sessionManager.get(chatId).then (session) =>
      @contextFromSession(session).then (context) ->
        promise.try -> cb(context)
      .then =>
        @sessionManager.save(chatId, session)


  ###
  Same as withContext, but with multiple ids.
  @param {Array<String>} chatIds
  @param {Function} cb function that invoke per each context
  ###
  withContexts: (chatIds, cb) ->
    @sessionManager.getMultiple(chatIds).map (session) =>
      @contextFromSession(session).then (context) ->
        promise.try -> cb(context)
      .then =>
        @sessionManager.save(session.meta.sessionId, session)

  ###
  Same as withContexts, but with all chats.
  @param {Function} cb function that invoke per each context
  ###
  withAllContexts: (cb) ->
    @sessionManager.getAll().map (session) =>
      @contextFromSession(session).then (context) ->
        promise.try -> cb(context)
      .then =>
        @sessionManager.save(session.meta.sessionId, session)


  ###
  Start listen updates via polling or web hook
  @return {Bot}
  ###
  listenUpdates: ->
    @_isListen = true
    @_initApi()
    @


  ###
  Stop listen updates via polling or web hook
  @return {Bot}
  ###
  stopListenUpdates: ->
    @_isListen = false
    @_initApi()
    @


  _initApi: ->
    @api?.destroy()
    options = {}
    if @_isListen
      if @config.webHook
        options.webHook = @config.webHook
        if @config.secure is false
          delete options.webHook.key
      else
        options.polling = @config.polling || true
    @api = new Api(@key, options)
    if @_isListen
      @api.on 'message', (msg) =>
        @_handleMessage(msg).catch (err) ->
          console.error(err, err.stack)
      if @config.webHook
        @_setWebhook()
      else
        @_unsetWebhook()
    # _.defer =>
    #   unless @_isListen
    #     @_unsetWebhook()


  _unsetWebhook: ->
    @api.setWebHook('')


  _setWebhook: ->
    @api.setWebHook(@config.webHook.url, @config.webHook.cert)


  _provideSessionId: (message) ->
    message.chat.id


  _handleMessage: (message) ->
    sessionId = @_provideSessionId(message)
    @sessionManager.get(sessionId).then (session) =>
      handler = new CommandHandler(message: message, bot: @, session: session)
      promise.try ->
        handler.handle()
      .then =>
        @sessionManager.save(sessionId, handler.session)


_.extend(Bot::, mixins)

module.exports = (config) -> new Bot(config)
module.exports.middlewares = require('./middlewares')