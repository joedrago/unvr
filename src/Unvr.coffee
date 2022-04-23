Bottleneck = require 'bottleneck'
fs = require 'fs'
path = require 'path'
{spawn, spawnSync} = require 'child_process'

coloristEXE = __dirname + "/../wbin/colorist.exe"
ffmpegEXE = __dirname + "/../wbin/ffmpeg.exe"
ffprobeEXE = __dirname + "/../wbin/ffprobe.exe"
nonaEXE = __dirname + "/../wbin/nona.exe"

DEFAULT_OUTPUT_WIDTH = 1920
DEFAULT_OUTPUT_HEIGHT = 1080
DEFAULT_FPS = 30
DEFAULT_FOV = 110
DEFAULT_ROTATED_FOV = 50
DEFAULT_CRF = 20

fatalError = (reason) ->
  throw new Error(reason)

deleteIfExists = (filename) ->
  if fs.existsSync(filename)
    fs.unlinkSync(filename)

clone = (o) ->
  return JSON.parse(JSON.stringify(o))

class Unvr
  constructor: (@srcFilename, opts) ->
    @looks = []
    @dstW = DEFAULT_OUTPUT_WIDTH
    @dstH = DEFAULT_OUTPUT_HEIGHT
    @basefov = DEFAULT_FOV
    @rangeStart = null
    @rangeEnd = null
    @step = 30
    @promiseLimiter = null
    @promiseStep = null
    @importCounter = 0
    @precache = false

    @locks = {}

    # Verbose: 0=Silent, 1=Progress, 2=Verbose
    @verboseLevel = 1
    if opts? and opts.verbose?
      @verboseLevel = opts.verbose

    @promiseMax = 3
    if opts? and opts.precache?
      @promiseMax = opts.precache

    load = true
    if opts? and opts.load?
      load = opts.load
    if load
      settingsFilename = @srcFilename + ".unvr"
      if fs.existsSync(settingsFilename)
        @progressLog("Loading pre-existing settings: #{settingsFilename}")
        json = fs.readFileSync(settingsFilename, "utf8")
        importData = JSON.parse(json)
        @verboseLog "Import Data: ", importData
        @import(importData)
    @getSourceDimensions()
    @prepareCacheDir()
    @nonaLies() # heat this cache up
    @updateStep()

  export: ->
    e = {
      @srcW
      @srcH
      @srcDuration
      @dstW
      @dstH
      @basefov
      @looks
      @rangeStart
      @rangeEnd
      @step
    }
    return e

  import: (e) ->
    for k, v of e
      this[k] = v
    @importCounter += 1
    @updateStep()

  progressLog: ->
    if @verboseLevel > 0
      console.log.apply(null, arguments)
  verboseLog: ->
    if @verboseLevel > 1
      console.log.apply(null, arguments)

  spawnPromise: (exe, args, opts) =>
    return new Promise (resolve, reject) =>
      @verboseLog "Spawning #{exe}: ", args
      p = spawn(exe, args, opts)
      p.on 'close', (code) =>
        resolve(code)

  setRange: (start, end) ->
    if not start? or not end?
      @rangeStart = null
      @rangeEnd = null
      return
    @rangeStart = start
    @rangeEnd = end

  insertLook: (afterIndex, timestamp, fov, pitch, yaw, roll) ->
    look = {timestamp, fov, pitch, yaw, roll}
    if (afterIndex < 0) or (@looks.length < 1)
      @looks.unshift look
    else
      @looks.splice(afterIndex+1, 0, look)

  getSourceDimensions: ->
    if not fs.existsSync(@srcFilename)
      fatalError "File does not exist: #{@srcFilename}"

    ffprobeArgs = [
      '-v'
      'error'
      '-select_streams'
      'v:0'
      '-show_entries'
      'stream=width,height,duration'
      '-of'
      'default=nw=1'
      @srcFilename
    ]

    @verboseLog "Querying width and height: #{@srcFilename}"
    proc = spawnSync(ffprobeEXE, ffprobeArgs)

    stdoutLines = String(proc.stdout).split(/\n/)
    @verboseLog stdoutLines
    for line in stdoutLines
      if matches = line.match(/width=(\d+)/)
        @srcW = parseInt(matches[1]) >> 1
      if matches = line.match(/height=(\d+)/)
        @srcH = parseInt(matches[1])
      if matches = line.match(/duration=(\d+)/)
        @srcDuration = parseInt(matches[1])

    @verboseLog "Probed source; dimensions: #{@srcW}x#{@srcH}, duration: #{@srcDuration}"
    if not @srcW? or not @srcH? or not @srcDuration?
      fatalError "Failed to find source dimensions and duration"

  calcBaseCacheFilename: (prefix, extension, cacheArgs) ->
    cacheArgKeys = Object.keys(cacheArgs).sort()
    filename = prefix
    for k in cacheArgKeys
      filename += "_#{k}_#{cacheArgs[k]}"
    if extension?
      filename += ".#{extension}"
    return filename
  calcCacheFilename: (prefix, extension, cacheArgs) ->
    return "#{@cacheDir}/" + @calcBaseCacheFilename(prefix, extension, cacheArgs)

  prepareCacheDir: ->
    parsed = path.parse(@srcFilename)
    @cacheDir = "./unvr.cache.#{parsed.name}"
    try
      fs.mkdirSync(@cacheDir)
    catch e
      # who cares
    if not fs.existsSync(@cacheDir)
      fatalError "Failed to create cache dir: #{@cacheDir}"

  getLook: (timestamp) ->
    prevLook = null
    for look in @looks
      if timestamp < look.timestamp
        break
      prevLook = look
    if not prevLook?
      prevLook =
        timestamp: 0
        roll:  0
        pitch: 0
        yaw:   0
        fov:   0
    return prevLook

  nonaLies: ->
    liesInputs = { @srcW, @srcH }
    nonaLiesFilename = @calcCacheFilename('nona_lies', 'png', liesInputs)
    if not fs.existsSync(nonaLiesFilename)
      await @spawnPromise(coloristEXE, ["generate", "#{liesInputs.srcW}x#{liesInputs.srcH},#000000", nonaLiesFilename])
    if not fs.existsSync(nonaLiesFilename)
      fatalError "Failed to make nona_lies.png"
    return @calcBaseCacheFilename('nona_lies', 'png', liesInputs)

  spawnOptions: ->
    if @verboseLevel > 1
      return {stdio: 'inherit'}
    return {stdio: 'ignore'}

  updateStep: ->
    if not @precache
      return
    if @step <= 1
      return
    if @promiseStep != null
      return
    if @promiseMax < 1
      return

    importCounterStart = @importCounter

    @promiseLimiter = new Bottleneck {
      maxConcurrent: @promiseMax
    }
    @promiseStep = @step
    @progressLog("Performing precache step(#{@promiseStep}, #{@promiseMax} concurrent)...")

    promises = []
    signals = { atLeastOneBailed: false }
    startRange = 0
    endRange = @srcDuration
    if @rangeStart? and @rangeEnd
      startRange = @rangeStart
      endRange = @rangeEnd
    for t in [startRange..endRange] by @promiseStep
      do (t, signals) =>
        promises.push @promiseLimiter.schedule =>
          return new Promise (resolve, reject) =>
            if importCounterStart != @importCounter
              @verboseLog "Bailing on generation of frame #{t}"
              signals.atLeastOneBailed = true
              resolve()
              return
            @preview(t).then ->
              resolve()
    await Promise.all(promises)
    if not signals.atLeastOneBailed
      @progressLog("Full precache step(#{@promiseStep}) complete.")
    if importCounterStart != @importCounter
      if @step == 1
        @progressLog("Step disabled (#{@promiseStep} -> #{@step}); Bailing out.")
      else
        @progressLog("Settings changed; Rescanning...")
      setTimeout =>
        @updateStep()
      , 100
    @promiseLimiter = null
    @promiseStep = null

  prepareNona: (look, timestamp) ->
    nonaInputs =
      dstW: @dstW
      dstH: @dstH
      fov: if look.fov > 0 then look.fov else @basefov
      roll: look.roll
      pitch: look.pitch
      yaw: look.yaw
      timestamp: timestamp
    return nonaInputs

  generateNona: (nonaInputs, look, timestamp) ->
    nonaConfigFilename = @calcCacheFilename('nona', 'cfg', nonaInputs)
    nonaXFilename = @calcCacheFilename('nona_x', 'tif', nonaInputs)
    nonaYFilename = @calcCacheFilename('nona_y', 'tif', nonaInputs)
    if not fs.existsSync(nonaConfigFilename) or not fs.existsSync(nonaXFilename) or not fs.existsSync(nonaYFilename)
      nonaFilePrefix = @calcCacheFilename('nona_tmp', null, { timestamp })
      nonaRawXFilename = nonaFilePrefix + "0000_x.tif"
      nonaRawYFilename = nonaFilePrefix + "0000_y.tif"
      deleteIfExists(nonaRawXFilename)
      deleteIfExists(nonaRawYFilename)
      deleteIfExists(nonaXFilename)
      deleteIfExists(nonaYFilename)
      nonaConfig = "p w#{nonaInputs.dstW} h#{nonaInputs.dstH} f0 v#{nonaInputs.fov}\ni f4 r#{nonaInputs.roll} p#{nonaInputs.pitch} y#{nonaInputs.yaw} v180 n\"#{await @nonaLies()}\"\n"
      nonaArgs = ['-o', nonaFilePrefix, '-c', nonaConfigFilename]
      @verboseLog nonaConfig
      fs.writeFileSync(nonaConfigFilename, nonaConfig)
      await @spawnPromise(nonaEXE, nonaArgs, @spawnOptions())
      if not fs.existsSync(nonaRawXFilename) or not fs.existsSync(nonaRawYFilename)
        fatalError "Failed to generate nona TIFFs"
      fs.renameSync(nonaRawXFilename, nonaXFilename)
      fs.renameSync(nonaRawYFilename, nonaYFilename)
      deleteIfExists(nonaFilePrefix + "0000.tif")
      deleteIfExists(nonaConfigFilename)
      if not fs.existsSync(nonaXFilename) or not fs.existsSync(nonaYFilename)
        fatalError "Failed to rename nona TIFFs"
    nona =
      inputs: nonaInputs
      x: nonaXFilename
      y: nonaYFilename
    return nona

  lock: (timestamp) ->
    return new Promise (resolve, reject) =>
      if not @locks[timestamp]
        # console.log "Locked: (#{timestamp})"
        @locks[timestamp] = true
        resolve()
        return

      waited = false
      interval = setInterval =>
        if @locks[timestamp]
          # console.log "Waiting for lock... (#{timestamp})"
          waited = true
        else
          # if waited
            # console.log "Finally got lock! (#{timestamp})"
          @locks[timestamp] = true
          # console.log "Locked: (#{timestamp})"
          clearInterval(interval)
          resolve()
      , 500

  unlock: (timestamp) ->
    if not @locks[timestamp]
      fatalError "Your lock code is garbage."
    # console.log "Unlocked: (#{timestamp})"
    @locks[timestamp] = false

  preview: (previewTimestamp) ->
    await @lock(previewTimestamp)

    look = @getLook(previewTimestamp)
    nonaInputs = @prepareNona(look, previewTimestamp)

    previewInputs = clone(nonaInputs)
    previewInputs.timestamp = previewTimestamp
    previewFilename = @calcCacheFilename("preview", "jpg", previewInputs)

    if not fs.existsSync(previewFilename)
      nona = await @generateNona(nonaInputs, look, previewTimestamp)

      ffmpegArgs = []

      ffmpegArgs.push '-ss'
      ffmpegArgs.push String(previewTimestamp)

      ffmpegArgs.push '-i'
      ffmpegArgs.push @srcFilename
      ffmpegArgs.push '-i'
      ffmpegArgs.push nona.x
      ffmpegArgs.push '-i'
      ffmpegArgs.push nona.y

      lookIndex = 0
      ffmpegFilter = ""
      ffmpegFilter += "[0:v]trim=start=0,fps=#{DEFAULT_FPS},setpts=PTS-STARTPTS[raw#{lookIndex}];"
      ffmpegFilter += "[raw#{lookIndex}][1][2]remap"

      ffmpegArgs.push "-filter_complex"
      ffmpegArgs.push ffmpegFilter
      ffmpegArgs.push '-an'
      ffmpegArgs.push '-frames:v'
      ffmpegArgs.push '1'

      ffmpegArgs.push previewFilename
      deleteIfExists(previewFilename)
      await @spawnPromise(ffmpegEXE, ffmpegArgs, @spawnOptions())
      if fs.existsSync(previewFilename)
        @progressLog("Generated preview for timestamp #{previewTimestamp}.")
      else
        await @spawnPromise(coloristEXE, ["generate", "#{@dstW}x#{@dstH},#ff00ff", previewFilename], @spawnOptions())
        @progressLog("Generated PLACEHOLDER preview for timestamp #{previewTimestamp}.")

      deleteIfExists(nona.x)
      deleteIfExists(nona.y)

    data = fs.readFileSync(previewFilename)
    @unlock(previewTimestamp)
    return data

  generate: (dstFilename) ->
    # Make a shallow copy of @looks so we can prepend/append
    looks = []
    for look in @looks
      looks.push look

    needsStartingLook = false
    if looks.length == 0
      needsStartingLook = true
    else if looks[0].timestamp != 0
      needsStartingLook = true
    if needsStartingLook
      startFOV = @basefov
      if looks.length > 0
        startFOV = looks[0].fov
      startingLook =
        timestamp: 0
        roll:  0
        pitch: 0
        yaw:   0
        fov:   startFOV
      looks.unshift startingLook

    lookFilenames = []
    for look, lookIndex in looks
      isLastLook = (lookIndex == (looks.length - 1))

      lookFilename = @calcCacheFilename("look", "mp4", { index: lookIndex })
      lookFilenames.push @calcBaseCacheFilename("look", "mp4", { index: lookIndex })

      nonaInputs = @prepareNona(look, 0)
      nona = await @generateNona(nonaInputs, look, 0)

      ffmpegArgs = []
      ffmpegArgs.push '-ss'
      ffmpegArgs.push String(look.timestamp)

      ffmpegArgs.push '-i'
      ffmpegArgs.push @srcFilename
      ffmpegArgs.push '-i'
      ffmpegArgs.push nona.x
      ffmpegArgs.push '-i'
      ffmpegArgs.push nona.y

      ffmpegFilter = ""

      duration = 0
      if lookIndex != (looks.length - 1)
        duration = looks[lookIndex+1].timestamp - look.timestamp
      if duration > 0
        ffmpegFilter += "[0:v]trim=start=0:duration=#{duration},fps=#{DEFAULT_FPS},setpts=PTS-STARTPTS[raw#{lookIndex}];"
      else
        ffmpegFilter += "[0:v]trim=start=0,fps=#{DEFAULT_FPS},setpts=PTS-STARTPTS[raw#{lookIndex}];"
      ffmpegFilter += "[raw#{lookIndex}][1][2]remap"
      ffmpegArgs.push "-filter_complex"
      ffmpegArgs.push ffmpegFilter
      ffmpegArgs.push '-an'

      if isLastLook && @rangeEnd?
        ffmpegArgs.push '-t'
        ffmpegArgs.push "#{@rangeEnd-look.timestamp}"

      ffmpegArgs.push '-crf'
      ffmpegArgs.push String(DEFAULT_CRF)
      ffmpegArgs.push '-g'
      ffmpegArgs.push '1'
      ffmpegArgs.push '-keyint_min'
      ffmpegArgs.push '1'

      ffmpegArgs.push lookFilename

      @progressLog "Rendering look #{lookIndex + 1}/#{looks.length} ..."
      deleteIfExists(lookFilename)
      await @spawnPromise(ffmpegEXE, ffmpegArgs, @spawnOptions())
      if not fs.existsSync(lookFilename)
        fatalError("Failed to generate look #{lookIndex}")

      deleteIfExists(nona.x)
      deleteIfExists(nona.y)

    @progressLog "Concatenating #{looks.length} video stream(s) ..."
    ffmpegArgs = []
    ffmpegFilter = ""
    concatString = ""
    filelist = ""
    filelistFilename = @calcCacheFilename("concatFileList", "txt", {})
    concatFilename = @calcCacheFilename("allvideo", "mp4", {})
    for lookFilename in lookFilenames
      filelist += "file '#{lookFilename}'\n"
    fs.writeFileSync(filelistFilename, filelist)
    ffmpegArgs.push '-f'
    ffmpegArgs.push 'concat'
    ffmpegArgs.push '-safe'
    ffmpegArgs.push '0'
    ffmpegArgs.push '-i'
    ffmpegArgs.push filelistFilename
    ffmpegArgs.push '-c'
    ffmpegArgs.push 'copy'
    ffmpegArgs.push concatFilename
    deleteIfExists(concatFilename)
    await @spawnPromise(ffmpegEXE, ffmpegArgs, @spawnOptions())

    @progressLog "Mixing video and audio streams ..."
    ffmpegArgs = []
    if @rangeStart?
      ffmpegArgs.push '-ss'
      ffmpegArgs.push "#{@rangeStart}"
    ffmpegArgs.push '-i'
    ffmpegArgs.push concatFilename
    if @rangeStart?
      ffmpegArgs.push '-ss'
      ffmpegArgs.push "#{@rangeStart}"
    ffmpegArgs.push '-i'
    ffmpegArgs.push @srcFilename
    ffmpegArgs.push '-c'
    ffmpegArgs.push 'copy'
    ffmpegArgs.push '-map'
    ffmpegArgs.push '0:v:0'
    ffmpegArgs.push '-map'
    ffmpegArgs.push '1:a:0'
    ffmpegArgs.push '-shortest'
    ffmpegArgs.push '-aspect'
    ffmpegArgs.push "#{@dstW}:#{@dstH}"
    ffmpegArgs.push dstFilename
    deleteIfExists(dstFilename)
    await @spawnPromise(ffmpegEXE, ffmpegArgs, @spawnOptions())
    if not fs.existsSync(dstFilename)
      fatalError "Failed to create final file."

    @progressLog "Generated: #{dstFilename}"
    return

module.exports = Unvr
