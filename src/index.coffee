_ = require 'lodash'
Bot = require './bot'

mother = (params) ->
  mother.createBot(params)

# global config
mother._globalConfig = {}

mother.createBot = (params) ->
  new Bot(_.extend({}, @_globalConfig, params))

# global config
mother.config = (config) ->
  return @_globalConfig unless config
  _.extend(@_globalConfig, config)
