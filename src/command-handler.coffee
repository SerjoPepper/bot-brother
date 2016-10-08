Context = require './context'
constants = require './constants'
promise = require 'bluebird'
_s = require 'underscore.string'
_ = require 'lodash'
emoji = require 'node-emoji'
ejs = require 'ejs'
co = require 'co'
Keyboard = require './keyboard'

resolveYield = (value) ->
  if value && (value.then || _.isObject(value) and value.toString() == '[object Generator]' || _.isFunction(value))
    value
  else
    Promise.resolve(value)

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
    @inlineQuery = params.inlineQuery
    @chosenInlineResult = params.chosenInlineResult
    @callbackQuery = params.callbackQuery
    @callbackData = params.callbackData
    @bot = params.bot
    @locale = params.prevHandler?.locale
    @session = params.session || {}
    @type = params.type # 'invoke'/'answer'/'synthetic'/'callback'
    @isRedirected = !!params.prevHandler
    @session.meta ||= {} # current, prev, from, chat
    @session.meta.user ||= @message?.from
    @session.meta.chat ||= @message?.chat
    @session.meta.sessionId ||= @provideSessionId()
    @session.data ||= {} # user data
    @session.backHistory || = {}
    @session.backHistoryArgs ||= {}
    @prevHandler = params.prevHandler
    @noChangeHistory = params.noChangeHistory
    @args = params.args
    @chain = [@bot]
    @middlewaresChains = @bot.getMiddlewaresChains([])

    @isSynthetic = params.isSynthetic
    @command = null
    @type = 'synthetic' if @isSynthetic
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
    if !@type && @message && !@prevHandler
      if @message?.text
        text = @message.text = _s.trim(@message.text)
        if text.indexOf('/') is 0
          @type = 'invoke'
          params = text.slice(1).split(/\s+|__/)
          @name = params[0].toLowerCase().replace(/@.+$/, '')
        else
          @type = 'answer'
          @name = @session.meta?.current
        if @type is 'answer' && !@name
          @name = 'start'
          @type = 'invoke'
          @args = []
      else if !@isSynthetic
        @type = 'answer'
        @name = @session.meta?.current

    if !@type && @callbackQuery
      @type = 'callback'

    @commandsChain = @bot.getCommandsChain(@name)
    if _.isString(@commandsChain[0]?.name)
      @command = @commandsChain[0]
    @chain = @bot.getCommandsChain(@name, includeBot: true)

    if @commandsChain.length
      if @type is 'invoke'
        @args ||= params?[1..] || []
    else if !@isSynthetic && @type is 'answer'
      @type = 'invoke'
      @name = @bot.getDefaultCommand()?.name
      @commandsChain = @bot.getCommandsChain(@name)

    return if !@name && !@isSynthetic && @type != 'callback'

    if @type is 'answer'
      @args = @session.invokeArgs
      unless _.isEmpty(@session.keyboardMap)
        @answer = @session.keyboardMap[@message.text]
        unless @answer?
          if @command?.compliantKeyboard || _.values(@session.keyboardMap).some((button) -> (button.requestContact || button.requestContact))
            @answer = value: @message.text
          else
            return
        else if @answer.go
          @goHandler = switch @answer.go
            when '$back'
              (ctx) -> ctx.goBack()
            when '$parent'
              (ctx) -> ctx.goParent()
            else
              (ctx) =>
                ctx.go(@answer.go, {args: @answer.args})
        # backward compatibility
        else if @answer.handler
          @goHandler = eval("(#{@answer.handler})")
      else
        @answer = value: @message.text

    if @type is 'invoke'
      @session.invokeArgs = @args
      if !@noChangeHistory && @prevHandler?.name && @prevHandler.name != @name
        @session.backHistory[@name] = @prevHandler.name
        @session.backHistoryArgs[@name] = @prevHandler.args
      @session.meta.current = @name
      _.extend(@session.meta, _.pick(@message, 'from', 'chat'))
      @session.meta.user = @message?.from || @session.meta.user

    if @type is 'callback' && !@prevHandler
      [_name, _args, _value, _callbackData...] = @callbackQuery.data.split('|')
      _callbackData = JSON.parse(_callbackData.join('|'))
      _args = _.compact(_args.split(','))
      @callbackData = _callbackData
      @goHandler = (ctx) -> ctx.go(_name, {
        args: _args
        value: _value
        callbackData: _callbackData
        callbackQuery: @callbackQuery
      })

    @middlewaresChains = @bot.getMiddlewaresChains(@commandsChain)

    @context.init()

    if @goHandler
      @executeMiddleware(@goHandler)
    else
      promise.resolve(
        _(constants.STAGES)
        .sortBy('priority')
        .reject('noExecute')
        .filter (stage) => !stage.type || stage.type is @type
        .map('name')
        .value()
      ).each (stage) =>
        # если в ответе есть обработчик - исполняем его
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
    text = if typeof textFn is 'function'
      textFn(data)
    else if !options.strict
      ejs.compile(key)(data)
    text


  ###
  @param {String} stage
  @return {Promise}
  ###
  executeStage: co.wrap (stage) ->
    for middleware in @middlewaresChains[stage] || []
      yield resolveYield(@executeMiddleware(middleware))


  ###
  @param {Function} middleware
  @return {Promise}
  ###
  executeMiddleware: co.wrap (middleware) ->
    unless @context.isEnded
      yield resolveYield(middleware(@context))


  ###
  Go to command

  @param {String} name command name
  @param {Object} params params
  @option params {Array<String>} [args] Arguments for command
  @option params {Boolean} [noChangeHistory] No change chain history
  ###
  go: (name, params = {}) ->
    message = _.extend({}, @message)
    [name, type] = name.split('$')
    if type is 'cb'
      type = 'callback'
    handler = new CommandHandler({
      name
      message
      bot: @bot
      session: @session
      prevHandler: @
      noChangeHistory: params.noChangeHistory
      args: params.args,
      callbackData: params.callbackData || @callbackData,
      type: params.type || type || 'invoke'
    })
    handler.handle()

  ###
  @return {String} Previous state name
  ###
  getPrevStateName: ->
    @session.backHistory[@name]

  getPrevStateArgs: ->
    @session.backHistoryArgs?[@name]

  ###
  Render keyboard
  @param {String} name custom keyboard name
  @return {Object} keyboard array of keyboard
  ###
  renderKeyboard: (name, params = {}) ->
    locale = @getLocale()
    chain = @getFullChain()
    data = @context.data
    isInline = params.inline
    keyboard = null
    for command in chain
      if command.prevKeyboard && !isInline
        return {prevKeyboard: true}
      keyboard = params.keyboard && new Keyboard(params.keyboard, params) ||
        command.getKeyboard(name, locale, params) ||
        command.getKeyboard(name, null, params)
      break if typeof keyboard != 'undefined'

    keyboard = keyboard?.render(locale, chain, data, @)
    if keyboard
      {markup, map} = keyboard
      unless isInline
        @session.keyboardMap = map
        @session.meta.current = @name
      markup
    else
      unless isInline
        @session.keyboardMap = {}
        @session.meta.current = @name
      null

  unsetKeyboardMap: ->
    @session.keyboardMap = {}

  resetBackHistory: ->
    unless @noChangeHistory
      currentBackName = @session.backHistory[@name]
      @session.backHistory[@name] = @session.backHistory[currentBackName]
      @session.backHistoryArgs[@name] = @session.backHistoryArgs[currentBackName]


module.exports = CommandHandler
