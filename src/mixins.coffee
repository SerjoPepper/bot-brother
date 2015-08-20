_ = require 'lodash'
ejs = require 'ejs'
Command = require './command'
constants = require './constants'
Keyboard = require './keyboard'
dot = require 'dot-object'


deepReplace = (val, fn) ->
  if _.isObject(val)
    for own k, v of val
      val[k] = deepReplace(fn(v, k), fn)
  else if _.isArray(val)
    for v, i in val
      val[i] = deepReplace(fn(v, i), fn)
  val

compileKeys = (obj) ->
  deepReplace obj, (val, k) ->
    if _.isString(val)
      val = ejs.compile(_s.trim(val))
    val

module.exports =


  # Add keyboard
  # @param {String} [name] keyboard name
  # @param {Array<Array>} keyboard keyboard markup
  # @param {Object} params params
  # @option params {String} [lang] a lang of keyboard
  # @option params {String} [type] row or table, default is table
  keyboard: (name, keyboard, params) ->
    # union format
    if !_.isString(name)
      params = keyboard
      keyboard = name
      name = constants.DEFAULT_KEYBOARD
    params ||= {}
    locale = params.locale || constants.DEFAULT_LOCALE
    @_keyboards ||= {}
    @_keyboards[locale] ||= {}
    @_keyboards[locale][name] = if keyboard then new Keyboard(keyboard, params, @) else null
    @

  getKeyboard: (name = constants.DEFAULT_KEYBOARD, locale = constants.DEFAULT_LOCALE, type) ->
    keyboard = @_keyboards?[locale]?[name]
    if type
      type == keyboard.type && keyboard
    else
      keyboard

  includeKeyboard: (name) ->


  # добавляем текста
  texts: (texts, params = {}) ->
    locale = params.locale || constants.DEFAULT_LOCALE
    @_texts ||= {}
    @_texts[locale] ||= {}
    _.merge(@_texts[locale], compileKeys(texts))
    @


  getText: (key, locale = constants.DEFAULT_LOCALE) ->
    dot.pick(key, @_texts?[locale])


  # добавляем middleware
  use: (type, [options]..., handler) ->
    @_middlewares ||= {}
    @_middlewares[type] ||= []
    @_middlewares[type].push(new Command(handler, options))
    @


  getMiddlewares: (type) ->
    @_middlewares[type] || []