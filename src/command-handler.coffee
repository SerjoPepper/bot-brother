Context = require './context'
constants = require './constants'
promise = require 'bluebird'
_s = require 'underscore.string'
_ = require 'lodash'
emoji = require 'node-emoji'
ejs = require 'ejs'

###
CommandHandler class
Creates for each incoming request.
###
class CommandHandler


  ###
  @param {Object} params the command handler params
  ###
  constructor: (params) ->
    @name = params.name
    @message = params.message
    @bot = params.bot
    @locale = params.prevHandler?.locale
    @session = params.session || {}
    @type = if @name then 'invoke' else null # 'invoke' or 'answer'
    @isRedirected = !!params.prevHandler
    @session.meta ||= {} # current, prev, from, chat
    @session.meta.user ||= @message?.from
    @session.meta.chat ||= @message?.chat
    @session.meta.sessionId ||= @provideSessionId()
    @session.data ||= {} # user data
    @session.backHistory || = {}
    @prevHandler = params.prevHandler
    @noChangeHistory = params.noChangeHistory
    @args = params.args
    @chain = []
    @middlewaresChains = @bot.getMiddlewaresChains([])

    @isSynthetic = params.isSynthetic
    @command = null
    @context = @prevHandler?.context.clone(@) || new Context(@)


  ###
  @param {String} locale current locale
  ###
  setLocale: (locale) ->
    @locale = locale
    @prevHandler?.setLocale(@locale)


  ###
  @return {String} current locale
  ###
  getLocale: ->
    @locale


  ###
  @return {String} sessionId
  ###
  provideSessionId: ->
    @session.meta.chat.id


  ###
  Start handling message
  @return {Promise}
  ###
  handle: ->
    if @message && !@prevHandler
      if @message?.text
        text = @message.text = _s.trim(@message.text)
        if text.indexOf('/') is 0
          @type = 'invoke'
          params = text.slice(1).split(/\s+/)
          @name = params[0]
        else
          @type = 'answer'
          @name = @session.meta?.current
      else
        @type = 'answer'
        @name = @session.meta?.current

    @commandsChain = @bot.getCommandsChain(@name)
    if _.isString(@commandsChain[0]?.name)
      @command = @commandsChain[0]
    @chain = @bot.getCommandsChain(@name, includeBot: true)

    if @commandsChain.length
      if @type is 'invoke'
        @args ||= params?[1..] || []
    else
      @type = 'invoke'
      @name = @bot.getDefaultCommand()?.name
      @commandsChain = @bot.getCommandsChain(@name)

    return if !@name && !@synthetic

    if @type is 'answer'
      @args = @session.invokeArgs
      unless _.isEmpty(@session.keyboardMap)
        @answer = @session.keyboardMap[@message.text]
        unless @answer?
          if @command?.compliantKeyboard
            @answer = value: @message.text
          else
            return
      else
        @answer = value: @message.text

    if @type is 'invoke'
      @session.invokeArgs = @args
      if !@noChangeHistory && @prevHandler?.name
        @session.backHistory[@name] = @prevHandler.name
      @session.meta.current = @name
      _.extend(@session.meta, _.pick(@message, 'from', 'chat'))
      @session.meta.user = @message?.from || @session.meta.user

    @middlewaresChains = @bot.getMiddlewaresChains(@commandsChain)

    @context.init()

    promise.resolve(
      _(constants.STAGES)
      .sortBy('priority')
      .reject('noExecute')
      .filter (stage) => !stage.type || stage.type is @type
      .map('name')
      .value()
    ).each (stage) =>
      # если в ответе есть обработчик - исполняем его
      if stage is 'answer' and (@answer?.handler? || @answer?.go?)
        if @answer?.go?
          go = @answer.go
          args = @answer.args
          @answer.handler = (ctx) -> ctx.go(go, {args: args})
        @executeMiddleware(@answer.handler)
      else
        @executeStage(stage)


  ###
  @return {Array} full command chain
  ###
  getFullChain: ->
    [@context].concat(@chain)


  ###
  Render text
  @param {String} key localization key
  @param {Object} data template data
  @param {Object} [options] options
  @return {String}
  ###
  renderText: (key, data, options = {}) ->
    locale = @getLocale()
    chain = @getFullChain()
    for command in chain
      textFn = command.getText(key, locale) || command.getText(key)
      break if textFn
    exData =
      render: (key) => @renderText(key, data, options)
    data = _.extend({}, exData, data)
    text = if textFn
      textFn(data)
    else if !options.strict
      ejs.compile(key)(data)
    text


  ###
  @param {String} stage
  @return {Promise}
  ###
  executeStage: (stage) ->
    promise.resolve(@middlewaresChains[stage] || []).each (middleware) =>
      @executeMiddleware(middleware)


  ###
  @param {Function} middleware
  @return {Promise}
  ###
  executeMiddleware: (middleware) ->
    promise.try =>
      unless @context.isEnded
        middleware(@context)


  ###
  Go to command

  @param {String} name command name
  @param {Object} params params
  @option params {Array<String>} [args] Arguments for command
  @option params {Boolean} [noChangeHistory] No change chain history
  ###
  go: (name, params = {}) ->
    message = _.extend({}, @message)
    handler = new CommandHandler({
      message: message
      bot: @bot
      session: @session
      prevHandler: @
      name: name
      noChangeHistory: params.noChangeHistory
      args: params.args
      isSynthetic: @isSynthetic
    })
    handler.handle()

  ###
  @return {String} Previous state name
  ###
  getPrevStateName: ->
    @session.backHistory[@name]

  ###
  Render keyboard
  @param {String} name custom keyboard name
  @return {Object} keyboard array of keyboard
  ###
  renderKeyboard: (name) ->
    locale = @getLocale()
    chain = @getFullChain()
    data = @context.data
    keyboard = null
    if _.isUndefined(name)
      keyboards = [
        @context.getKeyboard(null, locale)
        @context.getKeyboard()
        @command.getKeyboard(null, locale)
        @command.getKeyboard()
      ]
      for kb in keyboards
        unless _.isUndefined(kb)
          keyboard = kb
          break
    if !keyboard
      for command in chain
        keyboard = command.getKeyboard(name, locale)
        break if keyboard

    keyboard = keyboard?.render(locale, chain, data, @)
    if keyboard
      {markup: markup, map: map} = keyboard
      @session.keyboardMap = map
      markup
    else
      @session.keyboardMap = {}
      null




module.exports = CommandHandler
