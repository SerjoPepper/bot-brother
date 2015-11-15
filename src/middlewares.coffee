botanio = require 'botanio'

module.exports.botanio = (key) ->
  botan = botanio(key)
  (context) ->
    if !context.isBotanioTracked && !context.isSynthetic && !context.isRedirected
      context.isBotanioTracked = true
      botan.track(context.message, context.command.name)
      return

module.exports.typing = ->
  (context) ->
    context.bot.api.sendChatAction(context.meta.chat.id, 'typing')
    return