# Bot-brother
Node.js library to help you easy create telegram bots. Works on top of [node-telegram-bot-api](https://github.com/yagop/node-telegram-bot-api)
*Supports telegram-api 2.0 inline keyboards* 

Main features:
  - sessions
  - middlewares
  - localization
  - templated keyboards and messages
  - navigation between commands
  - inline keyboards

This bots work on top of **bot-brother**:
[@weatherman_bot](https://telegram.me/weatherman_bot)
[@zodiac_bot](https://telegram.me/zodiac_bot)
[@my_ali_bot](https://telegram.me/my_ali_bot)
[@delorean_bot](https://telegram.me/delorean_bot)
[@matchmaker_bot](https://telegram.me/matchmaker_bot)

## Table of contents
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Install](#install)
- [Simple usage](#simple-usage)
- [Examples of usage](#examples-of-usage)
- [Commands](#commands)
- [Middlewares](#middlewares)
  - [Predefined middlewares](#predefined-middlewares)
- [Sessions](#sessions)
  - [Redis storage](#redis-storage)
  - [With custom Redis-client](#with-custom-redis-client)
  - [Memory storage](#memory-storage)
  - [Your custom storage](#your-custom-storage)
- [Localization and texts](#localization-and-texts)
- [Keyboards](#keyboards)
  - [Going to command](#going-to-command)
  - [isShown flag](#isshown-flag)
  - [Localization in keyboards](#localization-in-keyboards)
  - [Keyboard templates](#keyboard-templates)
  - [Keyboard answers](#keyboard-answers)
  - [Inline 2.0 keyboards](#inline-20-keyboards)
- [Api](#api)
  - [Bot](#bot)
    - [bot.api](#botapi)
    - [bot.command](#botcommand)
    - [bot.keyboard](#botkeyboard)
    - [bot.texts](#bottexts)
    - [Using webHook](#using-webhook)
  - [Command](#command)
  - [Context](#context)
  - [Context properties](#context-properties)
    - [context.session](#contextsession)
    - [context.data](#contextdata)
    - [context.meta](#contextmeta)
    - [context.command](#contextcommand)
    - [context.answer](#contextanswer)
    - [context.message](#contextmessage)
    - [context.bot](#contextbot)
    - [context.isRedirected](#contextisredirected)
    - [context.isSynthetic](#contextissynthetic)
  - [Context methods](#context-methods)
    - [context.keyboard(keyboardDefinition)](#contextkeyboardkeyboarddefinition)
    - [context.hideKeyboard()](#contexthidekeyboard)
    - [context.inlineKeyboard(keyboardDefinition)](#contextinlinekeyboardkeyboarddefinition)
    - [context.render(key, data)](#contextrenderkey-data)
    - [context.go()](#contextgo)
    - [context.goParent()](#contextgoparent)
    - [context.goBack()](#contextgoback)
    - [context.repeat()](#contextrepeat)
    - [context.end()](#contextend)
    - [context.setLocale(locale)](#contextsetlocalelocale)
    - [context.getLocale()](#contextgetlocale)
  - [context.sendMessage(text, [options])](#contextsendmessagetext-options)
    - [context.forwardMessage(fromChatId, messageId)](#contextforwardmessagefromchatid-messageid)
  - [context.sendPhoto(photo, [options])](#contextsendphotophoto-options)
  - [context.sendAudio(audio, [options])](#contextsendaudioaudio-options)
  - [context.sendDocument(A, [options])](#contextsenddocumenta-options)
  - [context.sendSticker(A, [options])](#contextsendstickera-options)
  - [context.sendVideo(A, [options])](#contextsendvideoa-options)
  - [context.sendVoice(voice, [options])](#contextsendvoicevoice-options)
  - [context.sendChatAction(action)](#contextsendchatactionaction)
  - [context.getUserProfilePhotos([offset], [limit])](#contextgetuserprofilephotosoffset-limit)
  - [context.sendLocation(latitude, longitude, [options])](#contextsendlocationlatitude-longitude-options)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Install
```sh
npm install bot-brother
```

## Simple usage
```js
var bb = require('bot-brother');
var bot = bb({
  key: '<_TELEGRAM_BOT_TOKEN>',
  sessionManager: bb.sessionManager.memory(),
  polling: { interval: 0, timeout: 1 }
});

// Let's create command '/start'.
bot.command('start')
.invoke(function (ctx) {
  // Setting data, data is used in text message templates.
  ctx.data.user = ctx.meta.user;
  // Invoke callback must return promise.
  return ctx.sendMessage('Hello <%=user.first_name%>. How are you?');
})
.answer(function (ctx) {
  ctx.data.answer = ctx.answer;
  // Returns promise.
  return ctx.sendMessage('OK. I understood. You feel <%=answer%>');
});

// Creating command '/upload_photo'.
bot.command('upload_photo')
.invoke(function (ctx) {
  return ctx.sendMessage('Drop me a photo, please');
})
.answer(function (ctx) {
  // ctx.message is an object that represents Message.
  // See https://core.telegram.org/bots/api#message 
  return ctx.sendPhoto(ctx.message.photo[0].file_id, {caption: 'I got your photo!'});
});
```

## Examples of usage
We've written simple notification bot with `bot-brother`, so you can inspect code here: https://github.com/SerjoPepper/delorean_bot
<br>
You can try bot in action here:
https://telegram.me/delorean_bot

## Commands
Commands can be set with strings or regexps.
```js
bot.command(/^page[0-9]+/).invoke(function (ctx) {
  return ctx.sendMessage('Invoked on any page')
});

bot.command('page1').invoke(function (ctx) {
  return ctx.sendMessage('Invoked only on page1');
});

bot.command('page2').invoke(function (ctx) {
  return ctx.sendMessage('Invoked only on page2');
});
```


## Middlewares
Middlewares are useful for multistage command handling.
```js
var bb = require('bot-brother');
var bot = bb({
  key: '<_TELEGRAM_BOT_TOKEN>'
})

bot.use('before', function (ctx) {
  return findUserFromDbPromise(ctx.meta.user.id).then(function (user) {
    user.vehicle = user.vehicle || 'Car'
    // You can set any fieldname except following:
    // 1. You can't create fields starting with '_', like ctx._variable;
    // 2. 'bot', 'session', 'message', 'isRedirected', 'isSynthetic', 'command', 'isEnded', 'meta' are reserved names.
    ctx.user = user;
  });
});

bot.command('my_command')
.use('before', function (ctx) {
  ctx.user.age = ctx.user.age || '25';
})
.invoke(function (ctx) {
  ctx.data.user = ctx.user;
  return ctx.sendMessage('Your vehicle is <%=user.vehicle%>. Your age is <%=user.age%>.');
});
```
There are following stages, sorted in order of appearance.

| Name         | Description                    |
| ------------ | ------------------------------ |
| before       | applied before all stages      |
| beforeInvoke | applied before invoke stage    |
| beforeAnswer | applied before answer stage    |
| invoke       | same as `command.invoke(...)`  |
| answer       | same as `command.answer(...)`  |

Let's look at following example, and try to understand how and in what order they will be invoked.
```js
bot.use('before', function (ctx) {
  return ctx.sendMessage('bot before');
})
.use('beforeInvoke', function (ctx) {
  return ctx.sendMessage('bot beforeInvoke');
})
.use('beforeAnswer', function (ctx) {
  return ctx.sendMessage('bot beforeAnswer');
});

// This callback cathes all commands.
bot.command(/.*/).use('before', function (ctx) {
  return ctx.sendMessage('rgx before');
})
.use('beforeInvoke', function (ctx) {
  return ctx.sendMessage('rgx beforeInvoke');
})
.use('beforeAnswer', function (ctx) {
  return ctx.sendMessage('rgx beforeAnswer');
});

bot.command('hello')
.use('before', function (ctx) {
  return ctx.sendMessage('hello before');
})
.use('beforeInvoke', function (ctx) {
  return ctx.sendMessage('hello beforeInvoke');
})
.use('beforeAnswer', function (ctx) {
  return ctx.sendMessage('hello beforeAnswer');
})
.invoke(function (ctx) {
  return ctx.sendMessage('hello invoke');
})
.answer(function (ctx) {
  return ctx.go('world');
});

bot.command('world')
.use('before', function (ctx) {
  return ctx.sendMessage('world before');
})
.invoke(function (ctx) {
  return ctx.sendMessage('world invoke');
});
```

Bot dialog
```
me  > /hello
bot > bot before
bot > bot beforeInvoke
bot > rgx before
bot > rgx beforeInvoke
bot > hello before
bot > hello beforeInvoke
bot > hello invoke
me  > I type something
bot > bot before
bot > bot beforeAnswer
bot > rgx before
bot > rgx beforeAnswer
bot > hello beforeAnswer
bot > bot before // We've jumped to "world" command with "ctx.go('world')""
bot > bot beforeInvoke
bot > rgx before
bot > rgx beforeInvoke
bot > world before
bot > world invoke 
```

### Predefined middlewares
There are two predefined middlewares:
 - `botanio` - tracks each incoming message. See http://botan.io/
 - `typing` - shows typing status before each message. See https://core.telegram.org/bots/api#sendchataction

Usage:
```js
bot.use('before', bb.middlewares.typing());
bot.use('before', bb.middlewares.botanio('<BOTANIO_API_KEY>'));
```


## Sessions
Sessions can be implemented with Redis, with memory/fs storage or your custom storage
```js
bot.command('memory')
.invoke(function (ctx) {
  return ctx.sendMessage('Type some string');
})
.answer(function (ctx) {
  ctx.session.memory = ctx.session.memory || '';
  ctx.session.memory += ctx.answer;
  ctx.data.memory = ctx.session.memory;
  return ctx.sendMessage('Memory: <%=memory%>');
})
```

This dialog demonstrates how it works:
```
me  > /memory
bot > Type some string
me  > 1
bot > 1
me  > 2
bot > 12
me  > hello
bot > 12hello
```

### Redis storage
```
var bb = require('bot-brother')
bot = bb({
  key: '<_TELEGRAM_BOT_TOKEN>',
  sessionManager: bb.sessionManager.redis({port: '...', host: '...'}),
  polling: { interval: 0, timeout: 1 }
})
```
### With custom Redis-client
```
var bb = require('bot-brother')
bot = bb({
  key: '<_TELEGRAM_BOT_TOKEN>',
  sessionManager: bb.sessionManager.redis({client: yourCustomRedisConnection}),
  polling: { interval: 0, timeout: 1 }
})
```
### Memory storage
```
var bb = require('bot-brother')
bot = bb({
  key: '<_TELEGRAM_BOT_TOKEN>',
  // set the path where your session will be saved. You can skip this option
  sessionManager: bb.sessionManager.memory({dir: '/path/to/dir'}), 
  polling: { interval: 0, timeout: 1 }
})
```
### Your custom storage
```
var bb = require('bot-brother')
bot = bb({
  key: '<_TELEGRAM_BOT_TOKEN>',
  // set the path where your session will be saved. You can skip this option
  sessionManager: function (bot) {
    return bb.sessionManager.create({
      save: function (id, session) {
        // save session
        // should return promise
        return Promise.resolve(true)
      },
      get: function(id) {
        // get session by key
        // should return promise with {Object}
        return fetchYourSessionAsync(id)
      },
      getMultiple: function(ids) {
        // optionally method
        // define it if you use expression: bot.withContexts(ids)
        // should return promise with array of session objects
      },
      getAll: function() {
        // optionally method, same as 'getMultiple'
        // define it if you use bot.withAllContexts
      }
    })
  }, 
  polling: { interval: 0, timeout: 1 }
})
```


## Localization and texts
Localization can be used in texts and keyboards.
For templates we use [ejs](https://github.com/tj/ejs).
```js
// Setting keys and values for locale 'en'.
bot.texts({
  book: {
    chapter1: {
      page1: 'Hello <%=user.first_name%> :smile:'
    },
    chapter2: {
      page3: 'How old are you, <%=user.first_name%>?'
    }
  }
}, {locale: 'en'})

// Setting default localization values (used if key in certain locale did not found).
bot.texts({
  book: {
    chapter1: {
      page2: 'How are you, <%=user.first_name%>?'
    },
    chapter2: {
      page4: 'Good bye, <%=user.first_name%>.'
    }
  }
})

bot.use('before', function (ctx) {
  // Let's set data.user to Telegram user to use value in message templates.
  ctx.data.user = ctx.meta.user
  ctx.session.locale = ctx.session.locale || 'en';
  ctx.setLocale(ctx.session.locale);
});

bot.command('chapter1_page1').invoke(function (ctx) {
  ctx.sendMessage('book.chapter1.page1')
})
bot.command('chapter1_page2').invoke(function (ctx) {
  ctx.sendMessage('book.chapter1.page2')
})
bot.command('chapter2_page3').invoke(function (ctx) {
  ctx.sendMessage('book.chapter2.page3')
})
bot.command('chapter2_page4').invoke(function (ctx) {
  ctx.sendMessage('book.chapter2.page4')
})
```
When bot-brother sends a message, it tries to interpret this message as a key from your localization set. If key's not found, it interprets the message as a template with variables and renders it via ejs.
All local variables can be set via `ctx.data`.

Texts can be set for following entities:
  - bot
  - command
  - context

```js
bot.texts({
  book: {
    chapter: {
      page: 'Page 1 text'
    }
  }
});

bot.command('page1').invoke(function (ctx) {
  return ctx.sendMessage('book.chapter.page');
});

bot.command('page2').invoke(function (ctx) {
  return ctx.sendMessage('book.chapter.page');
})
.texts({
  book: {
    chapter: {
      page: 'Page 2 text'
    }
  }
});

bot.command('page3')
.use('before', function (ctx) {
  ctx.texts({
    book: {
      chapter: {
        page: 'Page 3 text'
      }
    }
  });
})
.invoke(function (ctx) {
  return ctx.sendMessage('book.chapter.page');
})
```

Bot dialog:

```
me  > /page1
bot > Page 1 text
me  > /page2
bot > Page 2 text
me  > /page3
bot > Page 3 text
```


## Keyboards
You can set keyboard for context, command or bot.
```js
// This keyboard is applied for any command.
// Also you can use emoji in keyboard.
bot.keyboard([
  [{':one: go page 1': {go: 'page1'}}],
  [{':two: go page 2': {go: 'page2'}}],
  [{':three: go page 3': {go: 'page3'}}]
])

bot.command('page1').invoke(function (ctx) {
  return ctx.sendMessage('This is page 1')
})

bot.command('page2').invoke(function (ctx) {
  return ctx.sendMessage('This is page 2')
}).keyboard([
  [{':one: go page 1': {go: 'page1'}}],
  [{':three: go page 3': {go: 'page3'}}]
])

bot.command('page3').invoke(function (ctx) {
  ctx.keyboard([
    [{':one: go page 1': {go: 'page1'}}]
    [{':two: go page 2': {go: 'page2'}}]
  ])
})
```

### Going to command
You can go to any command via keyboard. First argument for `go` method is a command name.
```
bot.keyboard([[
  {'command1': {go: 'command1'}}
]])

```


### isShown flag
`isShown` flag can be used to hide keyboard buttons in certain moment.

```
bot.use('before', function (ctx) {
  ctx.isButtonShown = Math.round() > 0.5;
}).keyboard([[
  {
    'text1': {
      go: 'command1',
      isShown: function (ctx) {
        return ctx.isButtonShown;
      }
    }
  }
]]);
```

### Localization in keyboards
```js
bot.texts({
  menu: {
    item1: ':one: page 1'
    item2: ':two: page 2'
  }
}).keyboard([
  [{'menu.item1': {go: 'page1'}}]
  [{'menu.item2': {go: 'page2'}}]
])
```

### Keyboard templates
You can use keyboard templates
```js
bot.keyboard('footer', [{':arrow_backward:': {go: 'start'}}])

bot.command('start', function (ctx) {
  ctx.sendMessage('Hello there')
}).keyboard([
  [{'Page 1': {go: 'page1'}}],
  [{'Page 2': {go: 'page2'}}]
])

bot.command('page1', function () {
  ctx.sendMessage('This is page 1')
})
.keyboard([
  [{'Page 2': {go: 'page2'}}],
  'footer'
])

bot.command('page2', function () {
  ctx.sendMessage('This is page 1')
})
.keyboard([
  [{'Page 1': {go: 'page1'}}],
  'footer'
])
```

### Keyboard answers
If you want to handle a text answer from your keyboard, use following code:
```js
bot.command('command1')
.invoke(function (ctx) {
  return ctx.sendMessage('Hello')
})
.keyboard([
  [{'answer1': 'answer1'}],
  [{'answer2': {value: 'answer2'}}],
  [{'answer3': 3}],
  [{'answer4': {value: 4}}]
])
.answer(function (ctx) {
  ctx.data.answer = ctx.answer;
  return ctx.sendMessage('Your answer is <%=answer%>');
});
```

Sometimes you want user to manually enter an answer. Use following code to do this:
```js
// Use 'compliantKeyboard' flag.
bot.command('command1', {compliantKeyboard: true})
.use('before', function (ctx) {
  ctx.keyboard([
    [{'answer1': 1}],
    [{'answer2': 2}],
    [{'answer3': 3}],
    [{'answer4': 4}]
  ]);
})
.invoke(function (ctx) {
  return ctx.sendMessage('Answer me!')
})
.answer(function (ctx) {
  if (typeof ctx.answer === 'number') {
    return ctx.sendMessage('This is an answer from keyboard')
  } else {
    return ctx.sendMessage('This is not an answer from keyboard. Your answer is: ' + ctx.answer)
  }
});
```

### Inline 2.0 keyboards
You can use inline keyboards in the same way as default keyboards
```js
bot.bommand('inline_example')
.answer(function (ctx) {
  ctx.sendMessage('Inline data example')
})
.callback(function (ctx) {
  ctx.updateText('Callback data: ' + ctx.callbackData.myVar)
})
// set any your data to callbackData.
// IMPORTANT! Try to fit your data in 60 chars, because Telegram has limit for inline buttons 
.inlineKeyboard([[
  {'Option 1': {callbackData: {myVar: 1}, isShown: function (ctx) { return ctx.callbackData.myVar != 1 }}},
  {'Option 2': {callbackData: {myVar: 2}, isShown: function (ctx) { return ctx.callbackData.myVar != 2 }}},
  // use syntax:
  // 'callback${{CALLBACK_COMMAND}}' (or 'cb${{CALLBACK_COMMAND}}') 
  // 'invoke${{INVOKE_COMMAND}}'
  // to go to another command
  {'Option 3': {go: 'cb$go_inline_example'}},
  {'Option 4': {go: 'invoke$go_inline_example'}}
]])

bot.command('go_inline_example')
.invoke(function (ctx) {
  ctx.sendMessage('This command invoked directly')
})
.callback(function (ctx) {
  ctx.updateText('Command invoked via callback! type /inline_example to start again')
})
```

## Api
There are three base classes:
  - Bot
  - Command
  - Context

### Bot
Bot represents a bot.
```
var bb = require('bot-brother');
var bot = bb({
  key: '<TELEGRAM_BOT_TOKEN>',
  // optional
  webHook: {
    url: 'https://mybot.com/updates',
    key: '<PEM_PRIVATE_KEY>',
    cert: '<PEM_PUBLIC_KEY>',
    port: 443,
    https: true
  }
})
```

Has following methods and fields:

#### bot.api
bot.api is an instance of [node-telegram-bot-api](https://github.com/yagop/node-telegram-bot-api)
```js
bot.api.sendMessage(chatId, 'message');
```

#### bot.command
Creates a command.
```js
bot.command('start').invoke(function (ctx) {
  ctx.sendMessage('Hello')
});
```

#### bot.keyboard
```js
bot.keyboard([
  [{column1: 'value1'}]
  [{column2: {go: 'command1'}}]
])
```


#### bot.texts
Defined texts can be used in keyboards, messages, photo captions
```js
bot.texts({
  key1: {
    embeddedKey2: 'Hello'
  }
})

// With localization.
bot.texts({
  key1: {
    embeddedKey2: 'Hello2'
  }
}, {locale: 'en'})
```


#### Using webHook
Webhook in telegram documentation: https://core.telegram.org/bots/api#setwebhook
If your node.js process is running behind the proxy (nginx for example) use following code.
We omit `webHook.key` parameter and run node.js on 3000 unsecure port.
```js
var bb = require('bot-brother');
var bot = bb({
  key: '<TELEGRAM_BOT_TOKEN>',
  webHook: {
    // Your nginx should proxy this to 127.0.0.1:3000
    url: 'https://mybot.com/updates',
    cert: '<PEM_PUBLIC_KEY>',
    port: 3000,
    https: false
  }
})
```

Otherwise if your node.js server is available outside, use following code:
```js
var bb = require('bot-brother');
var bot = bb({
  key: '<TELEGRAM_BOT_TOKEN>',
  webHook: {
    url: 'https://mybot.com/updates',
    cert: '<PEM_PUBLIC_KEY>',
    key: '<PEM_PRIVATE_KEY>',
    port: 443
  }
})
```

### Command
```js
bot.command('command1')
.invoke(function (ctx) {})
.answer(function (ctx) {})
.keyboard([[]])
.texts([[]])
```

### Context
The context is the essence that runs through all middlewares. You can put some data in the context and use this data in the next handler. Context is passed as the first argument in all middleware handlers.
```js
// this is handler is invoke
bot.use('before', function (ctx) {
  // 'ctx' is an instance of Context
  ctx.someProperty = 'hello';
});

bot.command('mycommand').invoke(function (ctx) {
  // You can use data from previous stage!
  ctx.someProperty === 'hello'; // true
});
```

You can put any property to context variable. But! You must observe the following rules:
  1. Property name can not start with an underscore. `ctx._myVar` - bad!, `ctx.myVar` - good.
  2. Names of properties should not overlap predefined properties or methods. `ctx.session = 'Hello'` - bad! `ctx.mySession = 'Hello'` - good.


### Context properties
Context has following predefined properties available for reading. Some of them are available for editing. Let's take a look at them:
#### context.session
You can put any data in context.session. This data will be available in commands and middlewares invoked for the same user.
Important! Currently for group chats session data is shared between all users in chat.

```js
bot.command('hello').invoke(function (ctx) {
  return ctx.sendMessage('Hello! What is your name?');
}).answer(function (ctx) {
  // Sets user answer to session.name.
  ctx.session.name = ctx.answer;
  return ctx.sendMessage('OK! I got it.')
});

bot.command('bye').invoke(function (ctx) {
  return ctx.sendMessage('Bye ' + ctx.session.name);
});
```

This is how it works:
```
me  > /hello
bot > Hello! What is your name?
me  > John
bot > OK! I remembered it.
me  > /bye
bot > Bye John
```

#### context.data
This variable works when rendering message texts. For template rendering we use (ejs)[https://github.com/tj/ejs]. All the data you put in context.data is available in the templates.
```
bot.texts({
  hello: {
    world: {
      friend: 'Hello world, <%=name%>!'
    }
  }
});

bot.command('hello').invoke(function (ctx) {
  ctx.data.name = 'John';
  ctx.sendMessage('hello.world.friend');
});
```

This is how it works:
```
me  > /hello
bot > Hello world, John!
```

There is predefined method `render` in context.data. It can be used for rendering embedded keys:
```
bot.texts({
  hello: {
    world: {
      friend: 'Hello world, <%=name%>!',
      bye: 'Good bye, <%=name%>',
      message: '<%=render("hello.world.friend")%> <%=render("hello.world.bye")%>'
    }
  }
});

bot.command('hello').invoke(function (ctx) {
  ctx.data.name = 'John';
  ctx.sendMessage('hello.world.message');
});
```

Bot dialog:
```
me  > /hello
bot > Hello world, John! Good bye, John
```


#### context.meta
context.meta contains following fields:
  - `user` - see https://core.telegram.org/bots/api#user
  - `chat` - see https://core.telegram.org/bots/api#chat
  - `sessionId` - key name for saving session, currently it is `meta.chat.id`. So for group chats your session data is shared between all users in chat.

#### context.command
Represents currently handled command. Has following properties:
 - `name` - the name of a command
 - `args` - arguments for a command
 - `type` - Can be `invoke` or `answer`. If handler is invoked with `.withContext` method, type is `synthetic`

Suppose that we have the following code:
```js
bot.command('hello')
.invoke(function (ctx) {
  var args = ctx.command.args.join('-');
  var type = ctx.command.type;
  var name = ctx.command.name;
  return ctx.sendMessage('Type '+type+'; Name: '+name+'; Arguments: '+args);
})
.answer(function (ctx) {
  var type = ctx.command.type;
  var name = ctx.command.name;
  var answer = ctx.answer;
  ctx.sendMessage('Type '+type+'; Name: '+name+'; Answer: ' + answer)
});
```

The result is the following dialogue:
```
me  > /hello world dear friend
bot > Type: invoke; Name: hello; Arguments: world-dear-friend
me  > bye
bot > Type: answer; Name: hello; Answer: bye
```

Also you can pass args in this way
```
me  > /hello__world
bot > Type: invoke; Name: hello; Arguments: world
me  > bye
bot > Type: answer; Name: hello; Answer: bye
```

#### context.answer
This is an answer for a command. Context.answer is defined only when user answers with a text message.

#### context.message
Represents message object. For more details see: https://core.telegram.org/bots/api#message

#### context.bot
Bot instance

#### context.isRedirected
Boolean. This flag is set to 'true' when a command was achieved via `go` method (user did not type text `/command` in bot).
Let's look at the following example:
```js
bot.command('hello').invoke(function (ctx) {
  return ctx.sendMessage('Type something.')
})
.answer(function (ctx) {
  return ctx.go('world');
});

bot.command('world').invoke(function (ctx) {
  return ctx.sendMessage('isRedirected: ' + ctx.isRedirected);
});
```
User was typing something like this:
```
me  > /hello
bot > Type something
me  > lol
bot > isRedirected: true
```

#### context.isSynthetic
Boolean. This flag is true when we achieve the handler with `.withContext` method.
```js
bot.use('before', function (ctx) {
  return ctx.sendMessage('isSynthetic before: ' + ctx.isSynthetic);
});

bot.command('withcontext', function (ctx) {
  return ctx.sendMessage('hello').then(function () {
    return bot.withContext(ctx.meta.sessionId, function (ctx) {
      return ctx.sendMessage('isSynthetic in handler: ' + ctx.isSynthetic);
    });
  });
})
```

Dialog with bot:
```
me  > /withcontext
bot > isSynthetic before: false
bot > hello
bot > isSynthetic before: true
bot > isSynthetic in handler: true
```


### Context methods
Context has the following methods.

#### context.keyboard(keyboardDefinition)
Sets keyboard
```js
ctx.keyboard([[{'command 1': {go: 'command1'}}]])
```

#### context.hideKeyboard()
```js
ctx.hideKeyboard()
```

#### context.inlineKeyboard(keyboardDefinition)
Sets keyboard
```js
ctx.keyboard([[{'command 1': {callbackData: {myVar: 2}}}]])
```


#### context.render(key, data)
Returns rendered text or key
```js
ctx.texts({
  localization: {
    key: {
      name: 'Hi, <%=name%> <%=secondName%>'
    }
  }
})
ctx.data.name = 'John';
var str = ctx.render('localization.key.name', {secondName: 'Doe'});
console.log(str); // outputs 'Hi, John Doe'
```

#### context.go()
Returns <code>Promise</code>
Goes to some command
```js
var command1 = bot.command('command1')
var command2 = bot.command('command2').invoke(function (ctx) {
  // Go to command1.
  return ctx.go('command1');
})
```

#### context.goParent()
Returns <code>Promise</code>
Goes to the parent command. A command is considered a descendant if its name begins with the parent command name, for example `setting` is a parent command, `settings_locale` is a descendant command.
```js
var command1 = bot.command('command1')
var command1Child = bot.command('command1_child').invoke(function (ctx) {
  return ctx.goParent(); // Goes to command1.
});
```

#### context.goBack()
Returns <code>Promise</code>
Goes to previously invoked command.
Useful in keyboard 'Back' button.
```js
bot.command('hello')
.answer(function (context) {
  return context.goBack()
})
// or
bot.keyboard([[
  {'Back': {go: '$back'}}
]])
```

#### context.repeat()
Returns <code>Promise</code>
Repeats current state, useful for handling wrong answers.
```js
bot.command('command1')
.invoke(function (ctx) {
  return ctx.sendMessage('How old are you?')
})
.answer(function (ctx) {
  if (isNaN(ctx.answer)) {
    return ctx.repeat(); // Sends 'How old are your?', calls 'invoke' handler.
  }
});
```

#### context.end()
Stops middlewares chain.

#### context.setLocale(locale)
Sets locale for the context. Use it if you need localization.
```js
bot.texts({
  greeting: 'Hello <%=name%>!'
})
bot.use('before', function (ctx) {
  ctx.setLocale('en');
});
```

#### context.getLocale()
Returns current locale

### context.sendMessage(text, [options])
Returns <code>Promise</code>
Sends text message.

**See**: https://core.telegram.org/bots/api#sendmessage

| Param | Type | Description |
| --- | --- | --- |
| text | <code>String</code> | Text or localization key to be sent |
| [options] | <code>Object</code> | Additional Telegram query options |

#### context.forwardMessage(fromChatId, messageId)
Returns <code>Promise</code>
Forwards messages of any kind.

| Param | Type | Description |
| --- | --- | --- |
| fromChatId | <code>Number</code> &#124; <code>String</code> | Unique identifier for the chat where the original message was sent |
| messageId | <code>Number</code> &#124; <code>String</code> | Unique message identifier |

### context.sendPhoto(photo, [options])
Returns <code>Promise</code>
Sends photo

**See**: https://core.telegram.org/bots/api#sendphoto

| Param | Type | Description |
| --- | --- | --- |
| photo | <code>String</code> &#124; <code>stream.Stream</code> | A file path or a Stream. Can also be a `file_id` previously uploaded |
| [options] | <code>Object</code> | Additional Telegram query options |

### context.sendAudio(audio, [options])
Returns <code>Promise</code>
Sends audio

**See**: https://core.telegram.org/bots/api#sendaudio

| Param | Type | Description |
| --- | --- | --- |
| audio | <code>String</code> &#124; <code>stream.Stream</code> | A file path or a Stream. Can also be a `file_id` previously uploaded. |
| [options] | <code>Object</code> | Additional Telegram query options |

### context.sendDocument(A, [options])
Returns <code>Promise</code>
Sends Document

**See**: https://core.telegram.org/bots/api#sendDocument

| Param | Type | Description |
| --- | --- | --- |
| A | <code>String</code> &#124; <code>stream.Stream</code> | file path or a Stream. Can also be a `file_id` previously uploaded. |
| [options] | <code>Object</code> | Additional Telegram query options |

### context.sendSticker(A, [options])
Returns <code>Promise</code>
Sends .webp stickers.

**See**: https://core.telegram.org/bots/api#sendsticker

| Param | Type | Description |
| --- | --- | --- |
| A | <code>String</code> &#124; <code>stream.Stream</code> | file path or a Stream. Can also be a `file_id` previously uploaded. |
| [options] | <code>Object</code> | Additional Telegram query options |

### context.sendVideo(A, [options])
Returns <code>Promise</code>
Use this method to send video files, Telegram clients support mp4 videos (other formats may be sent as Document).

**See**: https://core.telegram.org/bots/api#sendvideo

| Param | Type | Description |
| --- | --- | --- |
| A | <code>String</code> &#124; <code>stream.Stream</code> | file path or a Stream. Can also be a `file_id` previously uploaded. |
| [options] | <code>Object</code> | Additional Telegram query options |

### context.sendVoice(voice, [options])
Returns <code>Promise</code>
Sends voice

**Kind**: instance method of <code>[TelegramBot](#TelegramBot)</code>
**See**: https://core.telegram.org/bots/api#sendvoice

| Param | Type | Description |
| --- | --- | --- |
| voice | <code>String</code> &#124; <code>stream.Stream</code> | A file path or a Stream. Can also be a `file_id` previously uploaded. |
| [options] | <code>Object</code> | Additional Telegram query options |

### context.sendChatAction(action)
Returns <code>Promise</code>
Sends chat action.
`typing` for text messages,
`upload_photo` for photos, `record_video` or `upload_video` for videos,
`record_audio` or `upload_audio` for audio files, `upload_document` for general files,
`find_location` for location data.

**See**: https://core.telegram.org/bots/api#sendchataction

| Param | Type | Description |
| --- | --- | --- |
| action | <code>String</code> | Type of action to broadcast. |

### context.getUserProfilePhotos([offset], [limit])
Returns <code>Promise</code>
Use this method to get the list of profile pictures for a user.
Returns a [UserProfilePhotos](https://core.telegram.org/bots/api#userprofilephotos) object.

**See**: https://core.telegram.org/bots/api#getuserprofilephotos

| Param | Type | Description |
| --- | --- | --- |
| [offset] | <code>Number</code> | Sequential number of the first photo to be returned. By default, all photos are returned. |
| [limit] | <code>Number</code> | Limits the number of photos to be retrieved. Values between 1—100 are accepted. Defaults to 100. |

### context.sendLocation(latitude, longitude, [options])
Returns <code>Promise</code>
Sends location.
Use this method to send point on the map.

**See**: https://core.telegram.org/bots/api#sendlocation

| Param | Type | Description |
| --- | --- | --- |
| latitude | <code>Float</code> | Latitude of location |
| longitude | <code>Float</code> | Longitude of location |
| [options] | <code>Object</code> | Additional Telegram query options |
