// Generated by CoffeeScript 2.6.1
(function() {
  // ---------------------------------------------------------------------------------------
  // Globals
  var createSpinner, everIncrementing, findActiveLookIndex, refresh, scrubDelayTimeout, spin, spinTimeout, spinner, spinning, unvr, updateSettings;

  unvr = window.unvrInitData;

  everIncrementing = 1;

  // ---------------------------------------------------------------------------------------
  // Spinner Nonsense
  spinner = null;

  spinning = false;

  scrubDelayTimeout = null;

  spinTimeout = null;

  createSpinner = function() {
    var opts, target;
    opts = {
      lines: 13, // The number of lines to draw
      length: 38, // The length of each line
      width: 17, // The line thickness
      radius: 45, // The radius of the inner circle
      scale: 1, // Scales overall size of the spinner
      corners: 1, // Corner roundness (0..1)
      speed: 1, // Rounds per second
      rotate: 0, // The rotation offset
      animation: 'spinner-line-fade-quick', // The CSS animation name for the lines
      direction: 1, // 1: clockwise, -1: counterclockwise
      color: '#ffffff', // CSS color or array of colors
      fadeColor: 'transparent', // CSS color or array of colors
      top: '50%', // Top position relative to parent
      left: '50%', // Left position relative to parent
      shadow: '0 0 1px transparent', // Box-shadow for the lines
      zIndex: 2000000000, // The z-index (defaults to 2e9)
      className: 'spinner', // The CSS class to assign to the spinner
      position: 'relative' // Element positioning
    };
    target = document.getElementById('previewcontainer');
    return spinner = new Spinner(opts);
  };

  spin = function(enabled) {
    if (spinner == null) {
      return;
    }
    if (spinning === enabled) {
      return;
    }
    if (enabled) {
      spinning = true;
      if (spinTimeout != null) {
        clearTimeout(spinTimeout);
      }
      return spinTimeout = setTimeout(function() {
        spinner.spin(document.getElementById('previewcontainer'));
        return spinTimeout = null;
      }, 150);
    } else {
      spinning = false;
      if (spinTimeout != null) {
        clearTimeout(spinTimeout);
        return spinTimeout = null;
      } else {
        return spinner.stop();
      }
    }
  };

  // ---------------------------------------------------------------------------------------
  // Helpers
  window.updateRangeText = function(formElementId, outputElementId) {
    var v;
    v = document.getElementById(formElementId).value;
    return document.getElementById(outputElementId).innerHTML = `${v}`;
  };

  findActiveLookIndex = function() {
    var i, len, look, lookIndex, prevLookIndex, ref, scrubTimestamp;
    if (unvr.looks.length === 0) {
      return null;
    }
    scrubTimestamp = parseInt(document.getElementById('scrub').value);
    prevLookIndex = 0;
    ref = unvr.looks;
    for (lookIndex = i = 0, len = ref.length; i < len; lookIndex = ++i) {
      look = ref[lookIndex];
      // console.log "lookIndex #{lookIndex} look.timestamp #{look.timestamp} < scrubTimestamp #{scrubTimestamp}"
      if (scrubTimestamp < look.timestamp) {
        break;
      }
      prevLookIndex = lookIndex;
    }
    // console.log "prevLookIndex #{prevLookIndex}"
    return prevLookIndex;
  };

  // ---------------------------------------------------------------------------------------
  // UI Updates
  refresh = function() {
    var activeLook, activeLookIndex, checkValue, dstdim, dstdimString, html, i, len, look, lookClasses, lookIndex, looksElement, option, preview, rangesElement, ref, scrubTimestamp, step, stepString;
    scrubTimestamp = parseInt(document.getElementById('scrub').value);
    if ((scrubTimestamp >= 0) && (scrubTimestamp <= unvr.srcDuration)) {
      spin(true);
      preview = document.getElementById('preview');
      preview.src = `/preview/${scrubTimestamp}?${everIncrementing}`;
      everIncrementing += 1;
    }
    dstdim = document.getElementById('dstdim');
    dstdimString = `${unvr.dstW}x${unvr.dstH}`;
    dstdim.value = dstdimString;
    checkValue = dstdim.value;
    if (checkValue !== dstdimString) {
      // manually add it to the dropdown
      option = document.createElement("option");
      option.text = dstdimString;
      dstdim.add(option);
      dstdim.value = dstdimString;
    }
    step = document.getElementById('step');
    stepString = `${unvr.step}`;
    step.value = stepString;
    checkValue = step.value;
    if (checkValue !== stepString) {
      // manually add it to the dropdown
      option = document.createElement("option");
      option.text = stepString;
      step.add(option);
      step.value = stepString;
    }
    document.getElementById('basefov').value = unvr.basefov;
    activeLookIndex = findActiveLookIndex();
    if (activeLookIndex != null) {
      activeLook = unvr.looks[activeLookIndex];
      console.log("activeLook:", activeLook);
      document.getElementById('lookfov').value = activeLook.fov;
      document.getElementById('lookpitch').value = activeLook.pitch;
      document.getElementById('lookyaw').value = activeLook.yaw;
      document.getElementById('lookroll').value = activeLook.fov;
    }
    updateRangeText('scrub', 'scrubtext');
    updateRangeText('basefov', 'basefovtext');
    updateRangeText('lookfov', 'lookfovtext');
    updateRangeText('lookpitch', 'lookpitchtext');
    updateRangeText('lookyaw', 'lookyawtext');
    updateRangeText('lookroll', 'lookrolltext');
    rangesElement = document.getElementById('ranges');
    html = "";
    if ((unvr.rangeStart == null) || (unvr.rangeEnd == null)) {
      html = `<span class="rangeaction" onclick="onRangeButton('A')">[Set Start]</span>
<span class="rangeaction" onclick="onRangeButton('B')">[Set End]</span>`;
    } else {
      html = `<span class="rangeaction" onclick="onRangeButton('A')">[*]</span><span class="rangeaction" onclick="onJump(${unvr.rangeStart})"> Start [${unvr.rangeStart}]</span><br>
<span class="rangeaction" onclick="onRangeButton('B')">[*]</span><span class="rangeaction" onclick="onJump(${unvr.rangeEnd})"> End [${unvr.rangeEnd}]</span><br>
<span class="rangeaction" onclick="onRangeButton('R')">[Reset]</span>`;
    }
    rangesElement.innerHTML = html;
    looksElement = document.getElementById('looks');
    html = "";
    if (unvr.looks.length === 0) {
      html += `<div><span class="look" onclick="onNewLook(0)">Add Look</span></div>`;
    } else {
      ref = unvr.looks;
      for (lookIndex = i = 0, len = ref.length; i < len; lookIndex = ++i) {
        look = ref[lookIndex];
        if ((lookIndex === 0) && (look.timestamp !== 0)) {
          html += `<div><span class="look" onclick="onNewLook(-1)">Add Look Here</span></div>`;
        }
        lookClasses = "look";
        if (lookIndex === activeLookIndex) {
          lookClasses += " activelook";
        }
        html += `<div><span class="${lookClasses}" onclick="onLookDelete(${lookIndex})">[*] </span><span class="${lookClasses}" onclick="onLookSelect(${lookIndex})">Look ${lookIndex} - ${look.timestamp}</span></div>`;
        if ((lookIndex === activeLookIndex) && (scrubTimestamp !== look.timestamp)) {
          html += `<div><span class="look" onclick="onNewLook(${lookIndex})">Add Look Here</span></div>`;
        }
      }
    }
    looksElement.innerHTML = html;
    if (activeLookIndex != null) {
      return document.getElementById('lookcontrols').style.display = 'block';
    } else {
      return document.getElementById('lookcontrols').style.display = 'none';
    }
  };

  window.onPreviewImageLoaded = function() {
    return spin(false);
  };

  // ---------------------------------------------------------------------------------------
  // The big "update the server" hammer

  // Call this when you change anything in the unvr variable
  updateSettings = async function() {
    var response;
    spin(true);
    response = (await fetch("/set", {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(unvr)
    }));
    return response.json().then(function(data) {
      return refresh();
    });
  };

  // ---------------------------------------------------------------------------------------
  // Change Event Handlers
  window.onDstDimChange = function() {
    var dstdim, dstdimString, expectedString, pieces;
    dstdim = document.getElementById('dstdim');
    dstdimString = dstdim.value;
    expectedString = `${unvr.dstW}x${unvr.dstH}`;
    if (dstdimString === expectedString) {
      return;
    }
    pieces = dstdimString.split('x');
    unvr.dstW = parseInt(pieces[0]);
    unvr.dstH = parseInt(pieces[1]);
    return updateSettings();
  };

  window.onStepChange = function() {
    var expectedString, scrub, step, stepString;
    step = document.getElementById('step');
    stepString = step.value;
    expectedString = `${unvr.step}`;
    if (stepString === expectedString) {
      return;
    }
    unvr.step = parseInt(stepString);
    scrub = document.getElementById('scrub');
    if (unvr.step !== 1) {
      scrub.value = 0;
    }
    scrub.step = unvr.step;
    return updateSettings();
  };

  window.onBaseFovChange = function() {
    unvr.basefov = parseInt(document.getElementById('basefov').value);
    return updateSettings();
  };

  window.updateLookProp = function(propName, elementName) {
    var activeLook, lookIndex;
    lookIndex = findActiveLookIndex();
    if (lookIndex != null) {
      activeLook = unvr.looks[lookIndex];
      activeLook[propName] = parseInt(document.getElementById(elementName).value);
      return updateSettings();
    }
  };

  window.onRangeButton = function(which) {
    var timestamp;
    timestamp = parseInt(document.getElementById('scrub').value);
    if (which === 'R') {
      if (!confirm("Are you sure you want to reset the output range?")) {
        return;
      }
      unvr.rangeStart = null;
      unvr.rangeEnd = null;
    } else if (which === 'A') {
      if (!confirm("Are you sure you want to move the output range's start point?")) {
        return;
      }
      unvr.rangeStart = timestamp;
      if (unvr.rangeEnd == null) {
        unvr.rangeEnd = unvr.srcDuration;
      }
    } else {
      if (!confirm("Are you sure you want to move the output range's end point?")) {
        return;
      }
      unvr.rangeEnd = timestamp;
      if (unvr.rangeStart == null) {
        unvr.rangeStart = 0;
      }
    }
    return updateSettings();
  };

  window.onJump = function(newTimestamp) {
    var i, len, needsSettings, possibleStep, ref, scrubElement, step;
    step = unvr.step;
    if ((newTimestamp % step) !== 0) {
      ref = [300, 60, 30, 20, 10, 5, 1];
      for (i = 0, len = ref.length; i < len; i++) {
        possibleStep = ref[i];
        if (possibleStep > step) {
          continue;
        }
        if ((newTimestamp % possibleStep) === 0) {
          step = possibleStep;
          break;
        }
      }
    }
    needsSettings = unvr.step !== step;
    unvr.step = step;
    scrubElement = document.getElementById('scrub');
    scrubElement.step = step;
    scrubElement.value = newTimestamp;
    if (needsSettings) {
      return updateSettings();
    } else {
      return refresh();
    }
  };

  window.onLookSelect = function(lookIndex) {
    var newTimestamp;
    if ((lookIndex < 0) || (lookIndex >= unvr.looks.length)) {
      return;
    }
    newTimestamp = unvr.looks[lookIndex].timestamp;
    return onJump(newTimestamp);
  };

  window.onLookDelete = function(lookIndex) {
    var dyingLook;
    if ((lookIndex < 0) || (lookIndex >= unvr.looks.length)) {
      return;
    }
    dyingLook = unvr.looks[lookIndex];
    if (confirm(`Are you sure you want to delete Look ${lookIndex} (Timestamp: ${dyingLook.timestamp})?`)) {
      unvr.looks.splice(lookIndex, 1);
      return updateSettings();
    }
  };

  window.onNewLook = function(afterIndex) {
    var look, prevLook, scrubTimestamp;
    // console.log "onNewLook: #{afterIndex}"
    scrubTimestamp = parseInt(document.getElementById('scrub').value);
    prevLook = null;
    if ((afterIndex >= 0) && (afterIndex < unvr.looks.length)) {
      prevLook = unvr.looks[afterIndex];
    }
    look = {
      timestamp: scrubTimestamp,
      fov: 0,
      pitch: 0,
      yaw: 0,
      roll: 0
    };
    if (prevLook != null) {
      look.fov = prevLook.fov;
      look.pitch = prevLook.pitch;
      look.yaw = prevLook.yaw;
      look.roll = prevLook.roll;
    }
    if ((afterIndex < 0) || (unvr.looks.length < 1)) {
      unvr.looks.unshift(look);
    } else {
      unvr.looks.splice(afterIndex + 1, 0, look);
    }
    return updateSettings();
  };

  // ---------------------------------------------------------------------------------------
  // Scrub Handler

  // onScrubChange() is special as it simply moves the preview image, and doesn't "change anything" (in unvr).
  window.onScrubChange = function() {
    var timestamp;
    timestamp = parseInt(document.getElementById('scrub').value);
    // console.log "onScrub: ", timestamp
    spin(true);
    if (scrubDelayTimeout != null) {
      clearTimeout(scrubDelayTimeout);
    }
    return scrubDelayTimeout = setTimeout(function() {
      scrubDelayTimeout = null;
      return refresh();
    }, 50);
  };

  // ---------------------------------------------------------------------------------------
  // Init
  window.init = function() {
    var basefovElement, lookfovElement, lookpitchElement, lookrollElement, lookyawElement, scrubElement;
    console.log("init");
    // This fixes a dumb bug where dragging a range stops working if stuff is selected
    document.querySelectorAll('input[type="range"]').forEach(function(input) {
      return input.addEventListener('mousedown', function() {
        return window.getSelection().removeAllRanges();
      });
    });
    createSpinner();
    scrubElement = document.getElementById('scrub');
    scrubElement.min = 0;
    scrubElement.max = unvr.srcDuration;
    scrubElement.value = 0;
    scrubElement.step = unvr.step;
    basefovElement = document.getElementById('basefov');
    basefovElement.min = 0;
    basefovElement.max = 120;
    basefovElement.step = 10;
    basefovElement.value = unvr.basefov;
    lookfovElement = document.getElementById('lookfov');
    lookfovElement.min = 0;
    lookfovElement.max = 120;
    lookfovElement.step = 10;
    lookfovElement.value = unvr.basefov;
    lookpitchElement = document.getElementById('lookpitch');
    lookpitchElement.min = -50;
    lookpitchElement.max = 50;
    lookpitchElement.step = 1;
    lookpitchElement.value = 0;
    lookyawElement = document.getElementById('lookyaw');
    lookyawElement.min = -50;
    lookyawElement.max = 50;
    lookyawElement.step = 1;
    lookyawElement.value = 0;
    lookrollElement = document.getElementById('lookroll');
    lookrollElement.min = -50;
    lookrollElement.max = 50;
    lookrollElement.step = 1;
    lookrollElement.value = 0;
    return refresh();
  };

}).call(this);
