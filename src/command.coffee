_ = require 'lodash'
mixins = require './mixins'

class Command

  constructor: (name, params) ->
    @bot = params.bot
    name = name.toLowerCase() if _.isString(name)
    @name = name
    @isDefault = params.isDefault
    @compliantKeyboard = params.compliantKeyboard # стоит ли принимать ответы, если они не введены с клавиатуры

  invoke: (handler) ->
    @use('invoke', handler)

  answer: (handler) ->
    @use('answer', handler)

  callback: (handler) ->
    @use('callback', handler)


_.extend(Command::, mixins)


module.exports = Command
