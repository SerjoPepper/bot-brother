ejs = require 'ejs'
_ = require 'lodash'
emoji = require 'node-emoji'

###

Keyboard examples

[
  [
    {'text.key': 10}
    {'text.key1': {value: 10}}
    {'text.key2': {value: 10}}
    {key: 'text.key3', value: 'text.key3'}
    {text: 'Hello <%=user.name%>'} # raw text, which we compile
    {text: 'Hello <%=user.name%>', value: 'hello'} # raw text, which we compile
    'rowTemplate' # embed row
  ], [
    {'text.key': {go: 'state.name'}}
    {'text.key': {go: 'state.name'}}
    {'text.key': (ctx) -> $.goBack()}
    {'text.key': (ctx) -> $.goParent()}
    {'text.key': {handler: ($) -> $.goParent(), isShown: (ctx) -> ctx.data.user.age > 18}}
  ],
  'keyboardTemplate' # embed keyboard
]

###

KEYS = ['key', 'text', 'value', 'handler', 'go', 'isShown']

class Keyboard

  constructor: (keyboard, params, @command) ->
    @type = params.type || 'table' # 'table' or 'row'
    @keyboard = _.cloneDeep(keyboard).map (row, i) =>
      if @type is 'row' && _.isPlainObject(row)
        row = @processColumn(row)
      if _.isArray(row)
        row = row.map (column) =>
          if _.isPlainObject(column)
            column = @processColumn(column)
          column
      row


  processColumn: (column) ->
    keys = Object.keys(column)
    unless keys[0] in KEYS
      val = column[keys[0]]
      if _.isString(val)
        column = {key: keys[0], value: val}
      else if _.isFunction(val)
        column = {key: keys[0], handler: val}
      else
        column = {key: keys[0]}
        _.extend(column, val)
    if column.text
      column.text = ejs.compile(column.text)
    column


  replaceLayouts: (chain, locale) ->
    if @type is 'table'
      keyboard = []
      for row in @keyboard
        if _.isString(row)
          keyboard = keyboard.concat(@embedLayout(row, chain, locale, 'table'))
        else
          keyboard.push(row)
      for row, i in keyboard
        _row = []
        for column in row
          if _.isString(column)
            _row = _row.concat(@embedLayout(column, chain, locale, 'row'))
          else
            _row.push(column)
        keyboard[i] = _row
    else
      keyboard = []
      for column in @keyboard
        if _.isString(column)
          keyboard = keyboard.concat(@embedLayout(column, chain, locale, 'row'))
        else
          keyboard.push(column)
    keyboard



  embedLayout: (name, chain, locale, type) ->
    for command in chain
      keyboard = command.getKeyboard(name, locale, type) || command.getKeyboard(name, null, type)
      break if keyboard
    if !keyboard
      throw new Error("Can not find keyboard: #{name}")
    keyboard.replaceLayouts(chain, locale)


  render: (locale, chain, data, handler) ->
    keyboard = @replaceLayouts(chain, locale)
    map = {}
    markup = []
    for row in keyboard
      markupRow = []
      for column, i in row
        text = if column.text
          column.text(data)
        else
          handler.renderText(column.key, data)
        text = emoji.emojify(text)
        if !column.isShown || column.isShown(handler.context)
          markupRow.push(text)
          map[text] = {handler: column.handler, value: column.value, go: column.go, args: column.args}
      markup.push(markupRow) if markupRow.length

    {markup: markup, map: map}


module.exports = Keyboard