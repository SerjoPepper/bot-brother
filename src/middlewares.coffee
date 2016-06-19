botanio = require 'botanio'

module.exports.botanio = (key) ->
  botan = botanio(key)
  (context) ->
    if !context.isBotanioTracked && context.type != 'synthetic' && !context.isRedirected
      context.isBotanioTracked = true
      {message, inlineQuery, callbackQuery, command} = context
      botan.track(message || inlineQuery || callbackQuery, command.name)
      return

module.exports.typing = ->
  (context) ->
    if context.message && context.type != 'callback'
      context.bot.api.sendChatAction(context.meta.chat.id, 'typing')
      return