fs = require 'fs'
{spawn} = require 'child_process'
path = require 'path'
util = require 'util'
watch = require 'node-watch'

coffeeName = 'coffee'
if process.platform == 'win32'
  coffeeName += '.cmd'

buildEverything = (callback) ->
  try
    fs.mkdirSync 'build'
  catch
    # probably already exists

  coffee = spawn coffeeName, ['-c', '-o', 'build', 'src']
  coffee.stderr.on 'data', (data) ->
    process.stderr.write data.toString()
    process.exit(-1)
  coffee.stdout.on 'data', (data) ->
    print data.toString()
  coffee.on 'exit', (code) ->
  #   rawJS = fs.readFileSync('build/main.js')
  #   rawJS = "#!/usr/bin/env node\n\n" + rawJS
  #   fs.writeFileSync("build/unvr", rawJS)
    util.log "Compilation finished."
  #   callback?() if code is 0

task 'build', 'build', (options) ->
  buildEverything()

watchEverything = ->
  util.log "Watching for changes in src"
  watch ['src'], (evt, filename) ->
    parsed = path.parse(filename)
    # console.log parsed
    if parsed.ext == '.coffee'
      util.log "Source code #{filename} changed."
      util.log "Regenerating..."
      buildEverything()
  buildEverything()

task 'watch', 'watch everything', (options) ->
  watchEverything()
