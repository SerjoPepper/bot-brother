_ = require 'lodash'
mixins = require './mixins'
###
  - иерархия локализаций
    - определенный в контексте текущего обработчика
    - определенный в контексте текущей команды
    - определенный в контесте текущих шаблонных команд
    - определенный в контексте родительских команд
  - иерархия embed клавиатур
    - определенный в контексте текущего обработчика
    - определенный в контексте текущей команды
    - определенный в контесте текущих шаблонных команд
    - определенный в контексте родительских команд
  - иерархия middleware
    - before middleware
      - самый верхний родитель/родители
      - шаблоны
###

class Command

  constructor: (name, params) ->
    @bot = params.bot
    @name = name
    @isDefault = params.isDefault
    @compliantKeyboard = params.compliantKeyboard # стоит ли принимать ответы, если они не введены с клавиатуры

  invoke: (handler) ->
    @use('invoke', handler)

  answer: (handler) ->
    @use('answer', handler)


_.extend(Command::, mixins)


module.exports = Command
