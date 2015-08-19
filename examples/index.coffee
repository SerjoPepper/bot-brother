botMother = require 'bot-mother'

bot = botMother({key: 'apikey'})

bot.middleware(botMother.middlewares.session)

bot.preSeek ->
  @lang = lang
  @user = findUser
  @locals.user = @user
  @locals.lang =
  @session

bot.postAnswer ->
  @saveSession

bot.template('gender', '<%= user.name %>', {lang: 'ru'})

bot.middleware({

  post: ->

  pre: ->

  preInvoke: ->

  postInvoke: ->

  preAnswer: ->

  postAnswer: ->

})

bot.command('/settings')
  .keyboardTemplate('header', [[{a: 'a'}], [{b: 'b'}]], {lang: 'ru'})
  .keyboardRowTemplate('back', [{c: 'c'}, {d: 'd'}], {lang: 'ru'})

bot = botMother({key: 'apikey'})


bot.command('/settings_*')
  .middleware 'beforeInvoke', ->
    @settingsConstants = {a: 1}

bot.localization('ru', {

  hello: 'Privet'

})

bot.setTexts('ru', {

  hello: 'Privet'

})



command = bot.command('settings_avatar')
  .invoke ->
    #
    @sendPhoto('ola')
    @sendText('.ola')
  .answer ->
    @go()
  .middleware 'beforeInvoke', (cb) ->
  .middleware 'afterInvoke', (cb) ->
  .middleware 'beforeAnswer', (cb) ->
  .middleware 'afterAnswer', (cb) ->
  .middleware 'after', (cb) ->
  .middleware 'before', (cb) ->
  .answer ->
    @locals.user = user
  .template('hi', 'Hi <%= user.name %> <%= render("gender") %>', {lang: 'ru'})
  .keyboard([
    'header',
    [
      {
        handler: '/settings'
        text: {
          ru: '123'
        }

        show: ->
        '/settings': 'Hi from <%= user.name %> <%= render("gender") %>'
      }
      {'repeat()': 'Обновить'}
    ], [
      {bye: 'By from <%= user.name %>'}
      'button'
    ],
    'footer'
  ], {lang: 'ru'})

command.localization('ru', {

  'rubot.localization('ru', {

  hello: 'Privet'

})'

})

bot.command('/settings', {

  preSeek: ->

  postSeek: ->

    # returns promise
  invoke: (callback) ->
    @locals.a = 'b'
    @send('hi')
    @sendPhoto(photo, 'hi')
    @render()
    @go()
    @goParent()
    @repeat()
    @prevCommand
    @nextCommand
    @session
    # command plus arguments

  # returns promise
  answer: (callback) ->


})

command = bot.command({

  name: '/settings_name'

  parent: '/settings'

  # returns promise
  seek: (callback) ->

    @locals.a = 'b'
    @send('hi')
    @sendPhoto(photo, 'hi')
    @render()
    @go()
    @goParent()
    @repeat()
    @prevCommand
    @nextCommand
    # command plus arguments

  # returns promise
  answer: (callback) ->


})

command.middleware

command.template('hi', 'Hi <%= user.name %> <%= render("gender") %>', {lang: 'ru'})
command.keyboard([[
  {'/settings': 'Hi from <%= user.name %> <%= render("gender") %>'}
  {'repeat()': 'Обновить'}
], [
  {bye: 'By from <%= user.name %>'}
], 'footer'], {lang: 'ru'})
command.template('gender', '', {lang: 'ru'})

command.keyboardRow('header', [{'go("/start")': 'В начало'}], {lang: 'ru'})
command.keyboardRow('footer', [{'back()': 'Назад'}], {lang: 'ru'})
command.keyboardRow('footer', [{'back()': 'Назад'}], {lang: 'ru'})
command.keyboardButton('button', {'back()': 'Назад'})
bot.keyboardRow('settingsFooter', [
  {'back()': 'Назад'}
], {lang: 'ru'})

bot.listen() # начать получать сообщения

