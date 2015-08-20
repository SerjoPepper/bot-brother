Context = require './context'
constants = require './constants'
promise = require 'bluebird'
_s = require 'underscore.string'
_ = require 'lodash'
emoji = require 'node-emoji'

class CommandHandler

  constructor: (params) ->
    @name = params.name
    @message = params.message
    @bot = params.bot
    @locale = params.prevHandler?.locale
    @session = params.session || {}
    @type = null # 'invoke' or 'answer'
    @isRedirected = !!params.prevHandler
    @session.meta ||= {userId: @message.from.id} # current, prev, from, chat
    @session.data ||= {} # user data
    @prevHandler = params.prevHandler
    @isSynthetic = params.isSynthetic || @isRedirected
    @command = null # main command
    @context = @prevHandler?.context.clone(@) || new Context(@)


  setLocale: (locale) ->
    @locale = locale
    @prevHandler?.setLocale(@locale)


  getLocale: ->
    @locale

  handle: ->
    if @message?.text
      text = @message.text = _s.trim(@message.text)
      if text.indexOf('/') is 0
        @type = 'invoke'
        params = text.slice(1).split(/\s+/)
        @name = params[0]
      else
        @type = 'asnwer'
        @name = @session.meta?.current

    @commandsChain = @bot.getCommandsChain(@name)
    if _.isString(@commandsChain[0]?.name)
      @command = @commandsChain[0]
    @chain = @bot.getCommandsChain(@name, includeParent: true, includeBot: true)

    if @commandsChain.length
      if @type is 'invoke'
        @args = params[1..]
    else
      @type = 'invoke'
      @name = @bot.getDefaultCommand()?.name
      @commandsChain = @bot.getCommandsChain(@name)

    return if !@name && !@synthetic

    if @type is 'answer' && @session.keyboardMap
      @answer = @session.keyboardMap[@message.text]
      if !@answer && !@command?.compliantKeyboard
        return

    if @type is 'invoke'
      @session.meta.prev = @session.meta?.current
      @session.meta.current = @name
      _.extend(@session.meta, _.pick(@message, 'from', 'chat'))
      @session.meta.userId = @message.from.id

    @middlewaresChains = @bot.getMiddlewaresChains(@commandsChain)

    promise.resolve(
      _(constants.STAGES)
      .sortBy('priority')
      .reject('noExecute')
      .filter (stage) => !stage.type || stage.type is @type
      .map('name')
      .value().map (stage) =>
        # если в ответе есть обработчик - исполняем его
        if stage is 'answer' and @answer?.handler?
          @executeMiddleware(@answer.handler)
        else
          @executeStage(stage)
    )

  getFullChain: ->
    [@context].concat(@chain)

  renderText: (key, data) ->
    locale = @getLocale()
    chain = @getFullChain()
    for command in chain
      textFn = command.getText(key, locale) || command.getText(key)
      break if textFn
    text = if textFn
      textFn(data)
    else
      key
    text


  executeStage: (stage) ->
    promise.resolve(@middlewaresChains[stage] || []).map (middleware) =>
      @executeMiddleware(middleware)


  executeMiddleware: (middleware) ->
    callback = null
    cbPromise = promise.fromNode((cb) -> next = cb)
    resPromise = middleware(@context, (err) -> next(err))
    if typeof resPromise?.then is 'function'
      resPromise
    else
      cbPromise


  go: (name) ->
    message = _.pick(@message, 'from', 'chat')
    handler = new CommandHandler({
      message: message
      bot: @bot
      session: @session
      prevHandler: @
      name: name
    })
    handler.handle()

  # Render keyboard
  # @param {Object} data a data to render keyboard
  # @param {String} name custom keyboard name
  # @return {Object} object contains 'map' and 'markup' fields
  renderKeyboard: (name) ->
    locale = @getLocale()
    chain = @getFullChain()
    data = @context.data
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
    else if !name?
      return null
    else
      for command in chain
        keyboard = command.getKeyboard(name, locale)
        break if keyboard

    keyboard = keyboard?.render(locale, chain, data, handler)
    if keyboard
      {markup: markup, map: map} = keyboard
      @session.keyboardMap = map
      markup
    else
      null




module.exports = CommandHandler
