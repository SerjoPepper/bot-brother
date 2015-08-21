_ = require 'lodash'
emoji = require 'node-emoji'
mixins = require './mixins'

prepareText = (text) ->
  emoji.emojify(text)

RESTRICTED_PROPS = ['isRedirected', 'isSynthetic', 'message', 'session', 'bot', 'command']

class Context

  constructor: (handler) ->
    @_handler = handler
    @bot = @_handler.bot
    @session = @_handler.session.data
    @message = @_handler.message
    @isRedirected = @_handler.isRedirected # we transit to that state with go
    @isSynthetic = @_handler.isSynthetic
    @meta = @_handler.session.meta # команда
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

  init: ->
    @command = {
      name: @_handler.name
      args: @_handler.args
      type: @_handler.type
    }
    @answer = @_handler.answer?.value

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
    @go(@_handler.prev)

  repeat: ->
    @go(@_handler.name)

  clone: (handler) ->
    res = new Context(handler)
    setProps = Object.getOwnPropertyNames(@).filter (prop) ->
      !(prop in RESTRICTED_PROPS || prop.indexOf('_') is 0)
    # console.log('clone context', setProps)
    _.extend(res, _.pick(@, setProps))

  _withMiddlewares: (cb) ->
    @_handler.executeStage('beforeSend').then ->
      cb()
    .then =>
      @_handler.executeStage('afterSend')

  _prepareParams: (params = {}) ->
    markup = @_provideKeyboardMarkup()
    _params = {}
    if params.caption
      params.caption = @prepareText(params.caption)
    if markup
      _params.reply_markup = JSON.stringify(markup)
    _.extend(_params, params)

  _renderKeyboard: ->
    if @_temp.keyboardName is null
      null
    else
      @_handler.renderKeyboard(@_temp.keyboardName)

  _provideKeyboardMarkup: ->
    if @_temp.usePrevKeyboard
      null
    else
      markup = @_renderKeyboard()
      # console.log('markup')
      if markup
        keyboard: markup, resize_keyboard: true
      else
        hide_keyboard: true



_.extend(Context::, mixins)


module.exports = Context