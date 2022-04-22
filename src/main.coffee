Unvr = require('./Unvr')
fs = require('fs')

open = null
express = null
bodyParser = null

# console.log JSON.stringify(u.export(), null, 2)

# data = u.preview(500)
# console.log data.length

# u.addLook(0, 110, 0, 0, 0)
# u.addLook(20, 110, 0, 0, 15)
# u.setRange(5, 10)
# u.generate("out.mp4")

serve = (unvr) ->
  unvr.precache = true

  open = require('open')
  express = require 'express'
  bodyParser = require 'body-parser'

  app = express()
  http = require('http').createServer(app)

  app.get '/', (req, res) ->
    res.type('text/html')
    html = fs.readFileSync("#{__dirname}/../ui/index.html", "utf8")
    html = html.replace(/!UNVR_INIT_DATA!/, JSON.stringify(unvr.export()))
    res.send(html)
  app.get '/ui.js', (req, res) ->
    res.type('text/javascript')
    js = fs.readFileSync("#{__dirname}/../build/ui.js", "utf8")
    res.send(js)
  app.get '/preview/:timestamp', (req, res) ->
    res.type('image/jpeg')
    res.send(await unvr.preview(req.params.timestamp))
  app.get '/spin.umd.js', (req, res) ->
    res.type('text/javascript')
    res.send(fs.readFileSync("#{__dirname}/../ui/spin.umd.js"))
  app.use(bodyParser.json())
  app.post '/set', (req, res) ->
    # console.log req.body
    unvr.import(req.body)
    res.type('application/json')
    res.send(JSON.stringify(unvr.export()))

  http.listen 3123, '127.0.0.1', ->
    console.log "Listening: http://127.0.0.1:3123/"
    # open('http://127.0.0.1:3123/')

  process.on "SIGINT", ->
    console.log( "Saving settings..." );
    fs.writeFileSync("#{unvr.srcFilename}.unvr", JSON.stringify(unvr.export(), null, 2))
    process.exit()

main = ->
  argv = process.argv.slice(2)

  srcFilename = null
  dstFilename = null
  verbose = 1
  for arg in argv
    if arg == '-v'
      verbose = 2
    else if arg == '-q'
      verbose = 0
    else if not srcFilename?
      srcFilename = arg
    else if not dstFilename?
      dstFilename = arg
    else
      process.error "Too many arguments!"
      process.exit(-1)

  if not srcFilename?
    console.log "Syntax: unvr [-q|-v] src.mp4 [dst.mp4]"
    return

  unvr = new Unvr(srcFilename, { verbose: verbose })
  if dstFilename?
    await unvr.generate(dstFilename)
  else
    serve(unvr)

main()
