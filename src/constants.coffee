module.exports.STAGES = [
  {name: 'before', priority: 1, invert: true} # first execute
  {name: 'beforeInvoke', priority: 2, invert: true, type: 'invoke'}
  {name: 'beforeAnswer', priority: 3, invert: true, type: 'answer'}
  {name: 'invoke', priority: 4, type: 'invoke'}
  {name: 'answer', priority: 5, type: 'answer'}
  {name: 'beforeSend', priority: 6, noExecute: true, invert: true}
  {name: 'afterSend', priority: 7, noExecute: true}
  {name: 'afterAnswer', priority: 8, type: 'answer'}
  {name: 'afterInvoke', priority: 9, type: 'invoke'}
  {name: 'after', priority: 10}
]

module.exports.DEFAULT_LOCALE = 'default'

module.exports.DEFAULT_KEYBOARD = 'default_keyboard'