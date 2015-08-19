mother = require 'bot-mother'

bot = mother({key: 'lol'})

bot.getContext(id).then (context) ->
  context.go('settings', args: [])

bot.getContexts(ids).each (contexts) ->
  chat.sendMessage('hello!')

bot.allContexts().each (chat) ->
  chat.go('settings_lol')


