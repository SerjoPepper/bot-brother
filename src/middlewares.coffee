botanio = require 'botanio'

module.exports.botanio = (key) ->
  botan = botanio(key)
  (context) ->
    if !context.isSynthetic
      botan.track(context.message, context.command.name)

module.exports.typing = ->
  (context) ->
    @bot.api.sendChatAction(context.message.from.id, 'typing')