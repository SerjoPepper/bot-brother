# Bot-brother
Node.js library to help you easy create telegram bots. Work on top of [node-telegram-bot-api](https://github.com/yagop/node-telegram-bot-api)
Required Redis 2.8+

Main features:
  - sessions
  - middlewares
  - localization
  - templated keyboards and messages
  - navigation between commands

Supports commands, sessions and middlewares. Like express.js, but for bots :)
Works on Telegram api [Telegram Bot API](https://core.telegram.org/bots/api)


## Install
```sh
npm install bot-brother
```

## Simple usage
```js
var bb = require('bot-brother');
var bot = bb({
  key: '<_TELEGRAM_BOT_TOKEN>',
  redis: {port: 6379, host: '127.0.0.1'}
});

// create command 'start'
bot.command('start')
.invoke(function (ctx) {
  // set data, data is used in templates
  ctx.data.name = ctx.meta.user;
  // return promise
  return ctx.sendMessage('Hello <%=name%>. How are you?');
})
.answer(function (ctx) {
  ctx.data.answer = ctx.answer;
  // return promise
  return ctx.sendMessage('OK. I understood. You are <%=answer%>');
})

// start listen updates via polling
bot.listenUpdates();
```

## Commands
Commands can set via strings and regexps.
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
Middlewares are needed for multi stage command handling
```js
var bb = require('bot-brother');
var bot = bb({
  key: '<_TELEGRAM_BOT_TOKEN>',
  redis: {port: 6379, host: '127.0.0.1'}
})
bot.listenUpdates();

bot.use('before', function (ctx) {
  return findUserFromDbPromise(ctx.meta.user.id).then(function (user) {
    user.vehicle = user.vehicle || 'Car'
    // you can set any field name, except follow:
    // 1. fields, start with '_', like ctx._variable
    // 2. bot, session, message, isRedirected, isSynthetic, command, isEnded, meta
    ctx.user = user;
  });
});

bot.command('my_command')
.use('before', function (ctx) {
  ctx.user.age = ctx.user.age || '25';
})
.invoke(function (ctx) {
  ctx.data.user = ctx.user;
  // return promise
  return ctx.sendMessage('Your vehicle is <%=user.vehicle%>. Your age is <%=user.age%>.');
});
```
There are follow stages, sorted by invoking order.
| Name         | Description                    |
| ------------ | ------------------------------ |
| before       | applied before all stages      |
| beforeInvoke | applied before invoke stage    |
| beforeAnswer | applied before answer stage    |
| invoke       | same as `command.invoke(...)`  |
| answer       | same as `command.answer(...)`  |
| beforeSend   | applied before sending message |
| afterSend    | applied after sending message  |
| afterAnswer  | applied after answer stage     |
| afterInvoke  | applied after invoke stage     |
| after        | applied after all stages       |

Also there are predefined middlewares
 - botan.io (track each incoming message)
 - typing (show typing status before each message)

Usage:
```js
bb = require('bot-brother');
bot.use('before', bb.middlewares.typing());
bot.use('before', bb.middlewares.botanio('<BOTANIO_API_KEY>'));
```

## Sessions
Sessions work is based on Redis 2.8+
```js
bot.command('memory')
.invoke(function (ctx) {
  ctx.sendMessage('Type some string')
})
.answer(function (ctx) {
  ctx.session.memory = ctx.session.memory || ''
  ctx.session.memory += ctx.answer
  ctx.data.memory = ctx.session.memory
  ctx.sendMessage('Memory: <%=memory%>')
})
```


## Localization and texts
Localization can used in texts and keyboards
Templates use [ejs](https://github.com/tj/ejs).
```js
// set locales
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

// set default locales (used if key in certain locale did not found)
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
  ctx.data.user = ctx.meta.user // set data.user to Telegram user
  ctx.setLocale('en')
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

All local variables can be set via `ctx.data`
There are follow predefined locals:
 - `render`, can render other key. for example: `<%=render('other.key')%>`
```js
bot.use('before', function (ctx) {
  ctx.data.variable1 = 'Variable1 value'
  return ctx.sendMessage('before middleware; <%=variable1%>');
});
```

Texts can set for follow entities:
  - bot
  - command
  - context

```
bot.texts({
  book: {
    chapter: {
      page: 'Page text'
    }
  }
})
.use('before', function (ctx) {
  ctx.texts({
    book: {
      chapter: {
        page: 'Some another text'
      }
    }
  })
})

bot.command('page', function (ctx) {
  return ctx.sendMessage('book.chapter.page') // output 'Some another text'
})
.texts({
  book: {
    chapter: {
      page: 'Another text'
    }
  }
});
```

## Keyboards
You can set keyboard for context, command or bot
```js
// this keyboard is applied for any command
// also you can use emoji in keyboard
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

### Go to state
You can go to any state via keyboard
```
bot.keyboard([[
  {'command1': {go: 'command1'}}
]])

// or with this syntax
bot.keyboard([[
  {'command1': function (ctx) {return ctx.go('command1');}}
]])
```

### Embedded handler
You also can use embedded handler in keyboard. Important! you should not use outscope commands
```
bot.keyboard([[
  {
    'text1': {
      handler: function (ctx) {
        return ctx.sendMessage('This is my answer')
      }
    }
  }
]]);

// or with this syntax
bot.keyboard([[
  {
    'text1': function (ctx) {
      return ctx.sendMessage('Hello from there').then(function () {
        ctx.go('command1')
      })
    }
  }
]]);

// This does not work! Do not use outscope variables
var outScopeText = 'some text';
bot.keyboard([[
  {
    'text1': function (ctx) {
      return ctx.sendMessage('Hello from there. ' + outScopeText).then(function () {
        ctx.go('command1')
      })
    }
  }
]]);

bot.use('before', function (ctx) {
  ctx.data.outScopeText = outScopeText;
}).keyboard([[
  {
    'text1': function (ctx) {
      return ctx.sendMessage('Hello from there. <%=outScopeText%>').then(function () {
        ctx.go('command1');
      })
    }
  }
]]);
```

### 'isShown' flag
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

### Keyboard layouts
You can use keyboard layouts
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
When you want to handle text answer from your keyboard, use follow code:
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
  return ctx.sendMessage('Your answer <%=answer%>');
});
```

Sometimes you want that user manually enter the answer. Use follow code to do this
```js
// Use 'compliantKeyboard' flag
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
    return ctx.sendMessage('This is answer from keyboard')
  } else {
    return ctx.sendMessage('This is not answer from keyboard. Your answer: ' + ctx.answer)
  }
});
```

If you need to handle photos or other materials from message, use this code:
```js
bot.command('command1', {compliantKeyboard: true})
.invoke(function (ctx) {
  return ctx.sendMessage('Send me something');
})
.answer(function (ctx) {
  // handle message
  // see https://core.telegram.org/bots/api#message
  console.log(ctx.message)
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
  redis: {
    port: 6379,
    host: '127.0.0.1'
  },
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

Has follow methods:

#### bot.api
Api is instance of [node-telegram-bot-api](https://github.com/yagop/node-telegram-bot-api)
```js
bot.api.sendMessage(chatId, 'message');
```

#### bot.listenUpdates
Start listening updates via polling or webhook
```js
bot.listenUpdates();
```

#### bot.stopListenUpdates
Stop listen updates.
```js
bot.stopListenUpdates();
```

#### bot.command
Create command
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
Defined texts can use in  keyboards, messages, photo captions
```js
bot.texts({
  key1: {
    embeddedKey2: 'Hello'
  }
})

// with localization
bot.texts({
  key1: {
    embeddedKey2: 'Hello2'
  }
}, {locale: 'en'})
```


#### Using webHook
If your node.js is running behind the proxy (nginx for example) use follow code.
We omit `webHook.key` parameter and run node.js on 3000 unsecure port.
```js
var bb = require('bot-brother');
var bot = bb({
  key: '<TELEGRAM_BOT_TOKEN>',
  redis: {
    port: 6379,
    host: '127.0.0.1'
  },
  webHook: {
    url: 'https://mybot.com/updates', // your nginx from here should proxy to 127.0.0.1:3000
    cert: '<PEM_PUBLIC_KEY>',
    port: 3000,
    https: false
  }
})
```

Otherwise if your node.js server is available outside, use follow code:
```js
var bb = require('bot-brother');
var bot = bb({
  key: '<TELEGRAM_BOT_TOKEN>',
  redis: {
    port: 6379,
    host: '127.0.0.1'
  },
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


#### context.keyboard(keyboardDefinition)
Set keyboard
```js
ctx.keyboard([[{'command 1': {go: 'command1'}}]])
```

#### context.hideKeyboard()
No send keyboard
```js
ctx.hideKeyboard()
```

#### context.useKeyboard(keyboardName)
Use named keyboard (layout).
```js
ctx.keyboard('my_keyboard', [[...]])
ctx.useKeyboard('my_keyboard')
```

#### context.render(key)
Return rendered text or key
```js
ctx.texts({
  localization: {
    key: {
      name: '<%=name%>'
    }
  }
})
ctx.data.name = 'John'
var str = ctx.render('localization.key.name')
console.log(str)
```

#### context.go() ⇒ <code>Promise</code>
Go to some command
```js
var command1 = bot.command('command1')
var command2 = bot.command('command2').invoke(function (ctx) {
  // go to command1
  return ctx.go('command1');
})
```

#### context.goParent() ⇒ <code>Promise</code>
Go to parent command
```js
var command1 = bot.command('command1')
var command1Child = bot.command('command1_child').invoke(function (ctx) {
  return ctx.goParent(); // go to command1
});
```

#### context.goBack() ⇒ <code>Promise</code>
Go to previously invoked command.
Useful in keyboard 'Back' button.
```js
bot.keyboard([[
  {'Back': function (ctx) {return ctx.goBack();}}
]])
```

#### context.repeat() ⇒ <code>Promise</code>
Repeat current state, useful for handling wrong answers.
```js
bot.command('command1')
.invoke(function (ctx) {
  return ctx.sendMessage('How old are you?')
})
.answer(function (ctx) {
  if (isNaN(ctx.answer)) {
    return ctx.repeat(); // send 'How old are your?', call 'invoke' handler
  }
});
```

#### context.end()
Stop middlewares chain

#### context.setLocale(locale)
Set locale for context. Use it if you use localization
```js
bot.texts({
  greeting: 'Hello <%=name%>!'
})
bot.use('before', function (ctx) {
  ctx.setLocale('en')
});
```

#### context.getLocale()
Return current locale

### context.sendMessage(text, [options]) ⇒ <code>Promise</code>
Send text message.

**See**: https://core.telegram.org/bots/api#sendmessage

| Param | Type | Description |
| --- | --- | --- |
| text | <code>String</code> | Text  or localization key to be sent |
| [options] | <code>Object</code> | Additional Telegram query options |

#### context.forwardMessage(fromChatId, messageId) ⇒ <code>Promise</code>
Forward messages of any kind.

| Param | Type | Description |
| --- | --- | --- |
| fromChatId | <code>Number</code> &#124; <code>String</code> | Unique identifier for the chat where the original message was sent |
| messageId | <code>Number</code> &#124; <code>String</code> | Unique message identifier |

### context.sendPhoto(photo, [options]) ⇒ <code>Promise</code>
Send photo

**See**: https://core.telegram.org/bots/api#sendphoto

| Param | Type | Description |
| --- | --- | --- |
| photo | <code>String</code> &#124; <code>stream.Stream</code> | A file path or a Stream. Can also be a `file_id` previously uploaded |
| [options] | <code>Object</code> | Additional Telegram query options |

### context.sendAudio(audio, [options]) ⇒ <code>Promise</code>
Send audio

**See**: https://core.telegram.org/bots/api#sendaudio

| Param | Type | Description |
| --- | --- | --- |
| audio | <code>String</code> &#124; <code>stream.Stream</code> | A file path or a Stream. Can also be a `file_id` previously uploaded. |
| [options] | <code>Object</code> | Additional Telegram query options |

### context.sendDocument(A, [options]) ⇒ <code>Promise</code>
Send Document

**See**: https://core.telegram.org/bots/api#sendDocument

| Param | Type | Description |
| --- | --- | --- |
| A | <code>String</code> &#124; <code>stream.Stream</code> | file path or a Stream. Can also be a `file_id` previously uploaded. |
| [options] | <code>Object</code> | Additional Telegram query options |

### context.sendSticker(A, [options]) ⇒ <code>Promise</code>
Send .webp stickers.

**See**: https://core.telegram.org/bots/api#sendsticker

| Param | Type | Description |
| --- | --- | --- |
| A | <code>String</code> &#124; <code>stream.Stream</code> | file path or a Stream. Can also be a `file_id` previously uploaded. |
| [options] | <code>Object</code> | Additional Telegram query options |

### context.sendVideo(A, [options]) ⇒ <code>Promise</code>
Use this method to send video files, Telegram clients support mp4 videos (other formats may be sent as Document).

**See**: https://core.telegram.org/bots/api#sendvideo

| Param | Type | Description |
| --- | --- | --- |
| A | <code>String</code> &#124; <code>stream.Stream</code> | file path or a Stream. Can also be a `file_id` previously uploaded. |
| [options] | <code>Object</code> | Additional Telegram query options |

### context.sendVoice(voice, [options]) ⇒ <code>Promise</code>
Send voice

**Kind**: instance method of <code>[TelegramBot](#TelegramBot)</code>
**See**: https://core.telegram.org/bots/api#sendvoice

| Param | Type | Description |
| --- | --- | --- |
| voice | <code>String</code> &#124; <code>stream.Stream</code> | A file path or a Stream. Can also be a `file_id` previously uploaded. |
| [options] | <code>Object</code> | Additional Telegram query options |

### context.sendChatAction(action) ⇒ <code>Promise</code>
Send chat action.
`typing` for text messages,
`upload_photo` for photos, `record_video` or `upload_video` for videos,
`record_audio` or `upload_audio` for audio files, `upload_document` for general files,
`find_location` for location data.

**See**: https://core.telegram.org/bots/api#sendchataction

| Param | Type | Description |
| --- | --- | --- |
| action | <code>String</code> | Type of action to broadcast. |

### context.getUserProfilePhotos([offset], [limit]) ⇒ <code>Promise</code>
Use this method to get a list of profile pictures for a user.
Returns a [UserProfilePhotos](https://core.telegram.org/bots/api#userprofilephotos) object.

**See**: https://core.telegram.org/bots/api#getuserprofilephotos

| Param | Type | Description |
| --- | --- | --- |
| [offset] | <code>Number</code> | Sequential number of the first photo to be returned. By default, all photos are returned. |
| [limit] | <code>Number</code> | Limits the number of photos to be retrieved. Values between 1—100 are accepted. Defaults to 100. |

### context.sendLocation(latitude, longitude, [options]) ⇒ <code>Promise</code>
Send location.
Use this method to send point on the map.

**See**: https://core.telegram.org/bots/api#sendlocation

| Param | Type | Description |
| --- | --- | --- |
| latitude | <code>Float</code> | Latitude of location |
| longitude | <code>Float</code> | Longitude of location |
| [options] | <code>Object</code> | Additional Telegram query options |
