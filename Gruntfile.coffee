module.exports = (grunt) ->
  grunt.loadNpmTasks('grunt-coffeelint')
  grunt.loadNpmTasks('grunt-contrib-coffee')

  grunt.initConfig {
    coffeelint: {
      all: ['src/**/*.coffee']
      options: {
        configFile: 'coffeelint.json'
      }
    }
    coffee: {
      compile: {
        expand: true
        flatten: true
        cwd: './src/'
        src: ['*.coffee']
        dest: './lib/'
        ext: '.js'
      }
    }
  }

  grunt.registerTask 'prepublish', ['coffeelint', 'coffee:compile']