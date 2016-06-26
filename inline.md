bot.command('start')
.invoke (ctx) ->
  ctx.sendMessage()
.answer (ctx) ->
  ctx.sendMessage('done')
.inlineAnswer (ctx)
  ctx.updateMessage({
    message: '',
    inlineKeyboard: ''
  })
.keyboard()
.inlineKeyboard()

bot.invoke (ctx) ->
  yield ctx.sendMessage()
.answer (ctx) ->
  yield ctx.sendMessage()
.inlineAnswer (ctx) ->
  yield ctx.sendMessage()
  yield updateMessage(3)
// инлайн клавиатура ведет на ту же комманду, где она была объявлена
// при отсылке инлайн-клавиатуры, запоминаем название команды из которой она отправлена (запретить инлайн-обработчики)
.inlineKeyboard([])
.keyboard([])
  // установить клавиатуру для каждого значения
.chooseSuggestResult (ctx) ->

bot.inlineQuery()
.invoke (ctx) ->
.inlineAnswer (ctx) ->
.inlineKeyboard([
  
])

bot.command('weather_info')
.callback (ctx) ->
  # inline_query попадает в inlineAnswer
  {city, day} = ctx.inlineData
  forecast = fetchForecast({city, day})
  ctx.data = {forecast}
  yield ctx.updateText()
  yield ctx.updateDescription()
  yield ctx.updateInlineKeyboard()

  yield ctx.showTooltip(text)
  yield ctx.showAlert(text)  
.keyboard([])

.inlineKeyboard([])

# see https://core.telegram.org/bots/api#callbackquery
bot.withContext(sessionId, callbackQueryMessageId)
  ctx.updateText()
  ctx.updateDescription()
  ctx.updateInlineKeyboard()


bot.inlineQuery((ctx) ->
  # список сообщений, для каждого своя клавиатура
  messages = [
      {text: 'blabla'}
      {keyboard: [[{'fullweather': 'fullweather', data: {city: '', dayOffset: 1, detailed: false, command: 'start'}}]]}
  ]
  ctx.sendInlineResults(messages)

bot.inlineCommand 'fullweather', (ctx) ->
    ctx.inlineData === {a: 123}
    ctx.inlineKeyboard([[]])
    ctx.updateMessage(newText)


bot.inlineCommand 'todayweather', (ctx) ->
    ctx.inlineData === {a: 456}
    ctx.inlineKeyboard([[]])
    ctx.updateMessage(newText, keyboard)

bot-brother:
  - создание command-handler и context

telegram-node-bot-api:
Deprecate inline handlers +
Реализация клавиатур +
Реализация хранилищ +
Переходим на новый API +
Throttling на стороне bot-brother
Тесты



