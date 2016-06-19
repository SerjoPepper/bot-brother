exports.create = (methods) ->
  {save, get, getMultiple, getAll} = methods
  if !save || !get
    throw new Error('You should define "save" and "get" methods')
  methods

exports.redis = require './redis'
exports.memory = require './memory'
