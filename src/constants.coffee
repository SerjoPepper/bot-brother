module.exports.STAGES = [
  {name: 'before', priority: 1, invert: true} # first execute
  {name: 'beforeInvoke', priority: 2, invert: true, type: 'invoke'}
  {name: 'beforeAnswer', priority: 3, invert: true, type: 'answer'}
  {name: 'beforeSend', priority: 4, noExecute: true, invert: true}
  {name: 'afterSend', priority: 5, noExecute: true}
  {name: 'afterAnswer', priority: 6, type: 'answer'}
  {name: 'afterInvoke', priority: 7, type: 'invoke'}
  {name: 'after', priority: 8}
]

module.exports.DEFAULT_LOCALE = 'default'

module.exports.DEFAULT_KEYBOARD = 'default_keyboard'