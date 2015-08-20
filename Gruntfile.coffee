module.exports = (grunt) ->
  grunt.loadNpmTasks('grunt-coffeelint')

  grunt.initConfig {
    coffeelint: {
      all: ['src/**/*.coffee']
      options: {
        configFile: 'coffeelint.json'
      }
    }
  }