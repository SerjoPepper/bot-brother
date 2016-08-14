_ = require 'lodash'
emoji = require 'node-emoji'
mixins = require './mixins'
co = require 'co'

prepareText = (text) ->
  emoji.emojify(text)

RETRIABLE_ERRORS = ['ECONNRESET', 'ENOTFOUND', 'ESOCKETTIMEDOUT', 'ETIMEDOUT', 'ECONNREFUSED', 'EHOSTUNREACH', 'EPIPE', 'EAI_AGAIN']
RESTRICTED_PROPS = [
  'isRedirected', 'isSynthetic', 'message', 'session'
  'bot', 'command', 'isEnded', 'meta', 'type', 'args'
  'callbackData', 'inlineQuery', 'chosenInlineResult'
]
HTTP_RETRIES = 20

###
Context of the bot command

@property {Bot} bot
@property {Object} session
@property {Message} message telegram message
@property {Boolean} isRedirected
@property {Boolean} isSynthetic this context created with .withContext handler
@property {Boolean} isEnded this command is ended
@property {Object} data template data
@property {Object} meta meta information
@property {Object} command object tha represent current command. Has follow fields: name, args, type. Where type is 'answer' or 'invoke'
###
class Context

  constructor: (handler) ->
    @_handler = handler
    @bot = @_handler.bot
    @type = @_handler.type
    @session = @_handler.session.data
    @message = @_handler.message
    @callbackData = @_handler.callbackData
    @callbackQuery = @_handler.callbackQuery
    @isRedirected = @_handler.isRedirected # we transit to that state with go
    @isSynthetic = @_handler.isSynthetic
    @meta = @_handler.session.meta # команда
    @command = {
      name: @_handler.name
      args: @_handler.args
      type: @_handler.type
      callbackData: @_handler.callbackData
    }
    @args = @_handler.args
    @_api = @_handler.bot.api
    @_user = @_handler.session.meta.user
    @_temp = {} # dont clone
    @data = {} # template data

  setInlineQuery: (@inlineQuery) ->

  setChosenInlineResult: (@chosenInlineResult) ->

  ###
  Initialize
  ###
  init: ->
    @command = {
      name: @_handler.name
      args: @_handler.args
      type: @_handler.type
    }
    @args = @_handler.args
    @answer = @_handler.answer?.value

  ###
  Hide keyboard
  ###
  hideKeyboard: ->
    @useKeyboard(null)


  ###
  Use previous state keyboard
  @return {Context} this
  ###
  usePrevKeyboard: ->
    @_temp.usePrevKeyboard = true
    @


  ###
  Use named keyboard
  @return {Context} this
  ###
  useKeyboard: (name) ->
    @_temp.keyboardName = name
    @


  ###
  Use this method to get a list of profile pictures for a user.
  Returns a [UserProfilePhotos](https://core.telegram.org/bots/api#userprofilephotos) object.
  @param  {Number} [offset=0] Sequential number of the first photo to be returned. By default, offset is 0.
  @param  {Number} [limit=1] Limits the number of photos to be retrieved. Values between 1—100 are accepted. Defaults to 1.
  @return {Promise}
  @see https://core.telegram.org/bots/api#getuserprofilephotos
  ###
  getUserProfilePhotos: (offset = 0, limit = 1) ->
    @bot.api.getUserProfilePhotos(@_user.id, offset, limit)


  ###
  Render text
  @param {String} key text or key from localization dictionary
  @param {Object} options
  ###
  render: (key, data, options) ->
    @_handler.renderText(key, _.extend({}, @data, data), options)


  ###
  Send message
  @param {String} text text or key from localization dictionary
  @param {Object} params additional telegram params
  @return {Promise}
  @see https://core.telegram.org/bots/api#sendmessage
  ###
  sendMessage: (text, params = {}) ->
    if params.render != false
      text = @render(text)
    @_executeApiAction 'sendMessage', @meta.chat.id, prepareText(text), @_prepareParams(params)


  ###
  Same as sendMessage
  ###
  sendText: (key, params) ->
    @sendMessage(key, params)


  ###
  Send photo
  @param {String|stream.Stream} photo A file path or a Stream. Can also be a 'file_id' previously uploaded
  @param  {Object} [params] Additional Telegram query options
  @return {Promise}
  @see https://core.telegram.org/bots/api#sendphoto
  ###
  sendPhoto: (photo, params = {}) ->
    if params.caption
      if params.render != false
        params.caption = @render(params.caption)
      params.caption = prepareText(params.caption)
    @_executeApiAction 'sendPhoto', @meta.chat.id, photo, @_prepareParams(params)


  ###
  Forward message
  @param  {Number|String} fromChatId Unique identifier for the chat where the
  original message was sent
  @param  {Number|String} messageId  Unique message identifier
  @return {Promise}
  ###
  forwardMessage: (fromChatId, messageId) ->
    @_executeApiAction 'forwardMessage', @meta.chat.id, fromChatId, messageId


  ###
  Send audio
  @param  {String|stream.Stream} audio A file path or a Stream. Can also be a `file_id` previously uploaded.
  @param  {Object} [params] Additional Telegram query options
  @return {Promise}
  @see https://core.telegram.org/bots/api#sendaudio
  ###
  sendAudio: (audio, params) ->
    @_executeApiAction 'sendAudio', @meta.chat.id, audio, @_prepareParams(params)


  ###
  Send Document
  @param  {String|stream.Stream} doc A file path or a Stream. Can also be a `file_id` previously uploaded.
  @param  {Object} [params] Additional Telegram query options
  @return {Promise}
  @see https://core.telegram.org/bots/api#sendDocument
  ###
  sendDocument: (doc, params) ->
    @_executeApiAction 'sendDocument', @meta.chat.id, doc, @_prepareParams(params)


  ###
  Send .webp stickers.
  @param  {String|stream.Stream} sticker A file path or a Stream. Can also be a `file_id` previously uploaded.
  @param  {Object} [params] Additional Telegram query options
  @return {Promise}
  @see https://core.telegram.org/bots/api#sendsticker
  ###
  sendSticker: (sticker, params) ->
    @_executeApiAction 'sendSticker', @meta.chat.id, sticker, @_prepareParams(params)


  ###
  Send video files, Telegram clients support mp4 videos (other formats may be sent with `sendDocument`)
  @param  {String|stream.Stream} video A file path or a Stream. Can also be a `file_id` previously uploaded.
  @param  {Object} [params] Additional Telegram query options
  @return {Promise}
  @see https://core.telegram.org/bots/api#sendvideo
  ###
  sendVideo: (video, params) ->
    @_executeApiAction 'sendVideo', @meta.chat.id, video, @_prepareParams(params)


  ###
  Send chat action.
  `typing` for text messages,
  `upload_photo` for photos, `record_video` or `upload_video` for videos,
  `record_audio` or `upload_audio` for audio files, `upload_document` for general files,
  `find_location` for location data.
  @param  {Number|String} chatId  Unique identifier for the message recipient
  @param  {String} action Type of action to broadcast.
  @return {Promise}
  @see https://core.telegram.org/bots/api#sendchataction
  ###
  sendChatAction: (action) ->
    @_executeApiAction 'chatAction', @meta.chat.id, action


  ###
  Send location.
  Use this method to send point on the map.
  @param  {Float} latitude Latitude of location
  @param  {Float} longitude Longitude of location
  @param  {Object} [params] Additional Telegram query options
  @return {Promise}
  @see https://core.telegram.org/bots/api#sendlocation
  ###
  sendLocation: (latitude, longitude, params) ->
    @_executeApiAction 'sendLocation', @meta.chat.id, latitude, longitude, @_prepareParams(params)


  updateCaption: (text, params = {}) ->
    text = @render(text) if params.render != false
    _params = {
      reply_markup: @_provideKeyboardMarkup(inline: true)
    }
    if @callbackQuery.inline_message_id
      _params.inline_message_id = @callbackQuery.inline_message_id
    else
      _.extend(_params, {
        chat_id: @meta.chat.id
        message_id: @callbackQuery.message.message_id
      })
    @_executeApiAction 'editMessageCaption', prepareText(text), _.extend(_params, params)


  updateText: (text, params = {}) ->
    text = @render(text) if params.render != false
    _params = {
      reply_markup: @_provideKeyboardMarkup(inline: true)
    }
    if @callbackQuery.inline_message_id
      _params.inline_message_id = @callbackQuery.inline_message_id
    else
      _.extend(_params, {
        chat_id: @meta.chat.id
        message_id: @callbackQuery.message.message_id
      })
    @_executeApiAction 'editMessageText', prepareText(text), _.extend(_params, params)


  updateKeyboard: (params = {}) ->
    _params = {}
    if @callbackQuery.inline_message_id
      _params.inline_message_id = @callbackQuery.inline_message_id
    else
      _.extend(_params, {
        chat_id: @meta.chat.id
        message_id: @callbackQuery.message.message_id
      })
    @_executeApiAction 'editMessageReplyMarkup', @_provideKeyboardMarkup(inline: true), _.extend(_params, params)

  answerInlineQuery: (results, params) ->
    results.forEach (result) =>
      if result.keyboard
        result.reply_markup = inline_keyboard: @_renderKeyboard(inline: true, keyboard: result.keyboard)
        delete result.keyboard
    @_executeApiAction 'answerInlineQuery', @inlineQuery.id, results, params

  ###
  Set locale for context
  @param {String} locale Locale
  ###
  setLocale: (locale) ->
    @_handler.setLocale(locale)


  ###
  Get current context locale
  @return {String}
  ###
  getLocale: ->
    @_handler.getLocale()


  ###
  Go to certain command

  @param {String} name command name
  @param {Object} params params
  @option params {Array<String>} [args] Arguments for command
  @option params {Boolean} [noChangeHistory=false] No change chain history
  @option params {String} [stage='invoke'] 'invoke'|'answer'|'callback'
  @return {Promise}
  ###
  go: (name, params) ->
    @end()
    @_handler.go(name, params)

  ###
  Same as @go, but stage is 'callback'
  ###
  goCallback: (name, params) ->
    @go(name, _.extend(params, stage: 'callback'))

  ###
  Go to parent command.
  @return {Promise}
  ###
  goParent: ->
    @go(@_handler.name.split('_').slice(0, -1).join('_') || @_handler.name)


  ###
  Go to previous command.
  @return {Promise}
  ###
  goBack: ->
    prevCommandName = @_handler.getPrevStateName()
    @go(prevCommandName, {noChangeHistory: true, args: @_handler.getPrevStateArgs()})

  ###
  Repeat current command
  @return {Promise}
  ###
  repeat: ->
    @go(@_handler.name, {noChangeHistory: true, args: @command.args})


  ###
  Break middlewares chain
  ###
  end: ->
    @isEnded = true


  ###
  Clone context
  @param {CommandHandler} handler Command handler for new context
  @return {Context}
  ###
  clone: (handler) ->
    res = new Context(handler)
    setProps = Object.getOwnPropertyNames(@).filter (prop) ->
      !(prop in RESTRICTED_PROPS || prop.indexOf('_') is 0)
    _.extend(res, _.pick(@, setProps))


  _executeApiAction: (method, args...) ->
    @_handler.executeStage('beforeSend').then =>
      retries = HTTP_RETRIES
      execAction = =>
        @bot.rateLimiter(=> @_api[method](args...)).catch (e) ->
          httpCode = parseInt(e.message)
          if retries-- > 0 && (e?.code in RETRIABLE_ERRORS || 500 <= httpCode < 600 || httpCode is 420)
            execAction()
          else
            throw e
      execAction()
    .then co.wrap (message) =>
      if @_temp.inlineMarkupSent
        @_handler.resetBackHistory()
      else
        inlineMarkup = @_provideKeyboardMarkup(inline: true)
        if inlineMarkup && (method not in ['editMessageReplyMarkup', 'editMessageText', 'editMessageCaption']) && message?.message_id
          yield @_executeApiAction('editMessageReplyMarkup', JSON.stringify(inlineMarkup), {
            chat_id: @meta.chat.id
            message_id: message.message_id
          })
      @_handler.executeStage('afterSend').then -> message


  _prepareParams: (params = {}) ->
    markup = @_provideKeyboardMarkup()
    unless markup
      markup = @_provideKeyboardMarkup(inline: true)
      @_temp.inlineMarkupSent = true
    _params = {}
    if params.caption
      params.caption = prepareText(params.caption)
    if markup
      _params.reply_markup = JSON.stringify(markup)
    _.extend(_params, params)


  _renderKeyboard: (params) ->
    if @_temp.keyboardName is null && !params.inline
      null
    else
      @_handler.renderKeyboard(@_temp.keyboardName, params)


  _provideKeyboardMarkup: (params = {}) ->
    noPrivate = @meta.chat.type != 'private'
    if params.inline
      markup = @_renderKeyboard(params)
      if markup && !_.isEmpty(markup) && markup.some((el) -> !_.isEmpty(el))
        inline_keyboard: markup
      else
        null
    else
      # if @_handler.command?.compliantKeyboard && noPrivate
      #   force_reply: true
      # else
      if @_temp.usePrevKeyboard || @_usePrevKeyboard
        null
      else
        markup = @_renderKeyboard(params)
        if markup?.prevKeyboard
          null
        else
          if markup && !_.isEmpty(markup) && markup.some((el) -> !_.isEmpty(el))
            keyboard: markup, resize_keyboard: true
          else
            @_handler.unsetKeyboardMap()
            if noPrivate
              force_reply: true
            else
              hide_keyboard: true



_.extend(Context::, mixins)


module.exports = Context
