mother = require 'bot-mother'

bot = mother({key: 'my_key'})

command = bot.command('settings')

command.texts({

  message: 'Hello'

  keyboard: {
    cancel: 'cancel'
    locale: 'Поменять язык'
    name: 'Поменять имя'
  }

}, {locale: 'ru'})

.invoke (req, res, next) ->

  req.session
  req.data
  req.message
  req.api

  res.setLocale('ru')
  res.setData({user: user})
  res.sendPhoto()
  res.sendMessage()
  res.go()
  res.repeat()
  res.goBack()
  res.goParent()


  @session
  @data
  @render()
  @keyboard ''
  @sendMessage()
  @sendPhoto()
  next()

.answer (req, res, next) ->

.keyboard([
  [{
    text: 'keyboard.cancel', go: 'start', isShown: (req) ->
  }], [
    {
      'keyboard.locale': {go: 'settings_locale'}
    }
  ], [{
    'keyboard.name': {go: 'settings_name'}
  }]
])


bot.command('settings_*')
.keyboardEmbed('footer', [[{'keyboard.cancel': {goBack: true}}]])

bot.command('settings_name')
.texts({
  message: '<%=user.name%>, как вы хотите, чтобы вас звали?'
})
.keyboard([
  'footer'
])


bot.command('settings_locale')
.texts({
  message: 'Change your locale, <%=user.name%>'
  messageOk: 'All is ok!'
  locales: {
    ru: 'RU'
    en: 'EN'
  }
})
.answer ->

.invoke ->
  @keyboardEmbed('locales', [[
    {'locales.ru': 'RU'}
    {'locales.en': {value: 'EN', shown: ->}}
  ]])
.keyboard([
  'locales'
  'footer'
])