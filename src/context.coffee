_ = require 'lodash'
emoji = require 'node-emoji'
mixins = require './mixins'

prepareText = (text) ->
  emoji.emojify(text)

class Context

  constructor: (handler) ->
    @_handler = handler
    @bot = @_handler.bot
    @session = @_handler.session.data
    @message = @_handler.message
    @isRedirected = @_handler.isRedirected # we transit to that state with go
    @isSynthetic = @_handler.isSynthetic
    @meta = @_handler.session.meta # команда
    @answer = @_handler.answer
    @command = {
      name: @_handler.name
      args: @_handler.args
      type: @_handler.type
    }
    @_handler = handler
    @_api = @_handler.bot.api
    @_userId = @_handler.session.meta.userId
    @_temp = {} # dont clone
    @data = {} # template data

  hideKeyboard: ->
    @useKeyboard(null)

  # использовать предыдущую клавиатуру
  usePrevKeyboard: ->
    @_temp.usePrevKeyboard = true
    @

  useKeyboard: (name) ->
    @_temp.keyboardName = name
    @

  getUserProfilePhotos: (offset = 0, limit = 1) ->
    @bot.api.getUserProfilePhotos(@_userId, offset, limit)

  # render string
  render: (key) ->
    @_handler.renderText(key, @data)

  # send plain text, no rendered
  # @param text
  sendMessage: (text, params) ->
    @_withMiddlewares =>
      @_api.sendMessage(@_userId, prepareText(text), @_prepareParams(params))

  # send message
  # @param {String} key
  # @param {Object} params
  # @option params {String} keyboard custom keyboard
  sendText: (key, params) ->
    text = @render(key)
    @sendMessage(text, params)
      # TODO

  sendPhoto: (photo, params) ->
    @_withMiddlewares =>
      @_api.sendPhoto(@_userId, photo, @_prepareParams(params))

  forwardMessage: ->
    @_withMiddlewares =>
      @_api.forwardMessage()
      # TODO

  sendAudio: ->
    @_withMiddlewares =>
      @_api.sendAudio()
      # TODO

  sendDocument: ->
    @_withMiddlewares =>
      @_api.sendDocument()
      # TODO

  sendSticker: ->
    @_withMiddlewares =>
      @_api.sendSticker()
      # TODO

  sendVideo: ->
    @_withMiddlewares =>
      @_api.sendVideo()
      # TODO

  sendChatAction: ->
    @_withMiddlewares =>
      @_api.chatAction()
      # TODO

  sendLocation: ->
    @_withMiddlewares =>
      @_api.sendLocation()
      # TODO

  # устанавливаем локаль
  setLocale: (locale) ->
    @_handler.setLocale(locale)

  getLocale: ->
    @_handler.getLocale()

  go: (name) ->
    @_handler.go(name)

  goParent: ->
    @go(@_handler.name.split('_').slice(0, -1).join('_') || @_handler.name)

  goBack: ->
    @go(@_handler.session.meta.prev)

  repeat: ->
    @go(@_handler.name)

  clone: ->
    res = new Context(handler)
    Object.create(@, _.extend(_.pick(res, Object.getOwnPropertyNames(res)), {_temp: {}}))

  _withMiddlewares: (handler) ->
    @_handler.executeStage('beforeSend').then ->
      handler()
    .then =>
      @_handler.executeStage('afterSend')

  _prepareParams: (params = {}) ->
    markup = @_provideKeyboardMurkup()
    _params = {}
    if params.caption
      params.caption = @prepareText(params.caption)
    if markup
      _params.reply_murkup = JSON.stringify(markup)
    _.extend(_params, params)

  _renderKeyboard: ->
    if @_temp.keyboardName is null
      null
    else
      @_handler.renderKeyboard(@_temp.keyboardName)

  _provideKeyboardMurkup: ->
    if @_temp.usePrevKeyboard
      null
    else
      markup = @_renderKeyboard()
      if markup
        keyboard: markup, resize_keyboard: true
      else
        hide_keyboard: true



_.extend(Context::, mixins)


module.exports = Context