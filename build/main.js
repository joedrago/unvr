// Generated by CoffeeScript 2.6.1
(function() {
  var Unvr, bodyParser, express, fs, main, open, serve;

  Unvr = require('./Unvr');

  fs = require('fs');

  open = null;

  express = null;

  bodyParser = null;

  // console.log JSON.stringify(u.export(), null, 2)

  // data = u.preview(500)
  // console.log data.length

  // u.addLook(0, 110, 0, 0, 0)
  // u.addLook(20, 110, 0, 0, 15)
  // u.setRange(5, 10)
  // u.generate("out.mp4")
  serve = function(unvr) {
    var app, http;
    unvr.precache = true;
    open = require('open');
    express = require('express');
    bodyParser = require('body-parser');
    app = express();
    http = require('http').createServer(app);
    app.get('/', function(req, res) {
      var html;
      res.type('text/html');
      html = fs.readFileSync(`${__dirname}/../ui/index.html`, "utf8");
      html = html.replace(/!UNVR_INIT_DATA!/, JSON.stringify(unvr.export()));
      return res.send(html);
    });
    app.get('/ui.js', function(req, res) {
      var js;
      res.type('text/javascript');
      js = fs.readFileSync(`${__dirname}/../build/ui.js`, "utf8");
      return res.send(js);
    });
    app.get('/preview/:timestamp', async function(req, res) {
      res.type('image/jpeg');
      return res.send((await unvr.preview(req.params.timestamp)));
    });
    app.get('/spin.umd.js', function(req, res) {
      res.type('text/javascript');
      return res.send(fs.readFileSync(`${__dirname}/../ui/spin.umd.js`));
    });
    app.use(bodyParser.json());
    app.post('/set', function(req, res) {
      // console.log req.body
      unvr.import(req.body);
      res.type('application/json');
      return res.send(JSON.stringify(unvr.export()));
    });
    http.listen(3123, '127.0.0.1', function() {
      return console.log("Listening: http://127.0.0.1:3123/");
    });
    // open('http://127.0.0.1:3123/')
    return process.on("SIGINT", function() {
      console.log("Saving settings...");
      fs.writeFileSync(`${unvr.srcFilename}.unvr`, JSON.stringify(unvr.export(), null, 2));
      return process.exit();
    });
  };

  main = async function() {
    var arg, argv, dstFilename, i, len, srcFilename, unvr, verbose;
    argv = process.argv.slice(2);
    srcFilename = null;
    dstFilename = null;
    verbose = 1;
    for (i = 0, len = argv.length; i < len; i++) {
      arg = argv[i];
      if (arg === '-v') {
        verbose = 2;
      } else if (arg === '-q') {
        verbose = 0;
      } else if (srcFilename == null) {
        srcFilename = arg;
      } else if (dstFilename == null) {
        dstFilename = arg;
      } else {
        process.error("Too many arguments!");
        process.exit(-1);
      }
    }
    if (srcFilename == null) {
      console.log("Syntax: unvr [-q|-v] src.mp4 [dst.mp4]");
      return;
    }
    unvr = new Unvr(srcFilename, {
      verbose: verbose
    });
    if (dstFilename != null) {
      return (await unvr.generate(dstFilename));
    } else {
      return serve(unvr);
    }
  };

  main();

}).call(this);
