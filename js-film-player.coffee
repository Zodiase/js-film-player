(() ->
  FrameFactory = (options) ->
    if this not instanceof FrameFactory
      return new FrameFactory(options)
    #else
  
    _self = this
  
    _eventHandlers = {}
    _On = (eventName, handler) ->
      _eventHandlers[eventName] ?= []
      _eventHandlers[eventName].push(handler.bind(this))
      return this
    _Off = (eventName, handler) ->
      _eventHandlers[eventName] ?= []
      __handler = handler
      _eventHandlers[eventName] = _eventHandlers[eventName].filter (handler, index) ->
        return !(__handler == handler)
      return this
    _Trigger = (eventName, args...) ->
      _eventHandlers[eventName] ?= []
      handlers = _eventHandlers[eventName]
      for handler in handlers
        handler.call(null, args...)
      return this
    _One = (eventName, handler) ->
      _eventHandlers[eventName] ?= []
      __handler = (args...) ->
        handler.call(this, args...)
        this.off(eventName, handler)
        return
      _eventHandlers[eventName].push(__handler.bind(this))
      return this
  
    options ?= {}
  
    unless options.hasOwnProperty('constructor')
      throw new Error 'Frame constructor not defined.'
    #else
    unless options.constructor instanceof Function
      throw new Error 'Invalid frame constructor. Expected Function.'
    #else
    _frameConstructor = options.constructor
    
    unless options.hasOwnProperty('loader')
      throw new Error 'Frame loader not defined.'
    #else
    unless options.loader instanceof Function
      throw new Error 'Invalid frame loader. Expected Function.'
    #else
    _loader = options.loader
    
    _ready = false
    $_frameElement = $('<div>').addClass('frame')
    _internalData = {}
    
    ###
      Returns true if the frame is ready to be displayed, otherwise false.
      @return Boolean
    ###
    _IsReady = () ->
      return _ready
    ###
      Returns the jQuery wrapped frame element.
      @return jQuery.Element
    ###
    _Get$Element = () ->
      return $_frameElement
    ###
      Returns the frame element.
      @return HTMLElement
    ###
    _GetElement = () ->
      return $_frameElement[0]
    
    # APIs provided to constructor and loader functions.
    _internalAPI = {
      on: _On.bind(_internalAPI)
      off: _Off.bind(_internalAPI)
      trigger: _Trigger.bind(_internalAPI)
      one: _One.bind(_internalAPI)
      get$Element: _Get$Element
      getElement: _GetElement
      get: (key) ->
        return _internalData[key]
      set: (key, value) ->
        return _internalData[key] = value
      isReady: _IsReady
      ready: () ->
        if _IsReady()
          return true
        #else
        _ready = true
        #console.log('frame is ready', _self)
        _self.trigger('load')
        return true
    }
    
    ###
      Calls the loader if the frame is not ready, otherwise does nothing.
      The loader could potentially be called multiple times.
      @return null
    ###
    _Load = () ->
      if _IsReady()
        return
      #else
      _loader.apply(_internalAPI, [])
      return
    
    ##== public apis ==##
    this.on = _On.bind(this)
    this.off = _Off.bind(this)
    this.trigger = _Trigger.bind(this)
    this.one = _One.bind(this)
    
    this.isReady = _IsReady
    this.load = _Load
    ###
      Makes the frame element behind all the others.
      @return null
    ###
    this.sendToBack = () ->
      $_frameElement.addClass('at-back').removeClass('at-front')
      return
    ###
      Makes the frame element in front of all the others.
      @return null
    ###
    this.bringToFront = () ->
      $_frameElement.addClass('at-front').removeClass('at-back')
      return
    this.get$Element = _Get$Element
    this.getElement = _GetElement
    
    ##== events ==##
    this.on 'stage', () ->
      _frameConstructor.apply(_internalAPI, [$_frameElement])
      return true
    
    return this
  #/FrameFactory
  
  FilmFactory = (options) ->
    unless this instanceof FilmFactory
      return new FilmFactory(options)
    #else
  
    _self = this
  
    _eventHandlers = {}
    this.on = (eventName, handler) ->
      _eventHandlers[eventName] ?= []
      _eventHandlers[eventName].push(handler)
      return _self
    this.off = (eventName, handler) ->
      _eventHandlers[eventName] ?= []
      __handler = handler
      _eventHandlers[eventName] = _eventHandlers[eventName].filter (handler, index) ->
        return !(__handler == handler)
      return _self
    this.trigger = (eventName, args...) ->
      _eventHandlers[eventName] ?= []
      handlers = _eventHandlers[eventName]
      for handler in handlers
        handler.call(_self, args...)
      return _self
    this.one = (eventName, handler) ->
      _eventHandlers[eventName] ?= []
      __handler = (args...) ->
        handler.call(_self, args...)
        _self.off(eventName, handler)
        return
      _eventHandlers[eventName].push(__handler)
      return _self
  
    options ?= {}
  
    unless options.target instanceof HTMLElement
      throw new Error 'Invalid target. Expected HTMLElement.'
    #else
    _sceneElement = options.target
    $_sceneElement = $(options.target)
    $_backStageElement = $('<div>').css(
      'position': 'absolute'
      'top': '0'
      'right': '0'
      'bottom': '0'
      'left': '0'
      'visibility': 'hidden'
      'pointer-events': 'none'
    )
    $_backStageElement.appendTo($_sceneElement)
    _preloadBeforeStarting = Boolean(options.preloadBeforeStarting)
    
    unless typeof options.fps is 'number'
      throw new Error 'Invalid fps. Expected Number.'
    #else
    unless options.fps > 0
      throw new Error 'Invalid fps. Expected positive number.'
    #else
    _timePerFrame = 1000 / options.fps
    _frames = []
    _nextFrameIndex = -1
    _playing = false
    _paused = false
    _buffering = false
    _currentFrame = null
    _preloadQueue = []
    _preloading = false
    _playTimer = 0
    
    ###
      Returns the number of frames in the animation.
      @return Number
    ###
    _CountFrames = () ->
      return _frames.length
    ###
      Stops the animation if playing and triggers 'stop' event.
      If not playing, does nothing.
      @return null
    ###
    _Stop = () ->
      if not _playing
        return
      #else
      
      # Stop the animation.
      clearTimeout(_playTimer)
      _playTimer = 0
      _playing = false
      
      #! Load blank frame.
      if _currentFrame
        _currentFrame.sendToBack()
        $_backStageElement.append(_currentFrame.get$Element())
        _currentFrame.trigger('hide')
      
      _self.trigger('stop')
      console.log('stopped')
      return
    ###
      Enter the buffering state until the specified frame is ready.
      Try to load the frame right now, unlike _Preload which uses a queue.
      When the frame is ready, exit buffering state and resume playing.
      @return null
    ###
    _Buffer = (frame) ->
      if frame.isReady()
        #setTimeout(_playFrame, 0)
        _playFrame()
        return
      #else
      console.log('buffering frame', frame)
      _buffering = true
      frame.on 'load', () ->
        console.log('buffering frame complete', frame)
        _buffering = false
        #setTimeout(_playFrame, 0)
        _playFrame()
        return
      frame.load()
      return
    ###
      Preload doesn't enter buffering state. Instead it has its own queue
      for loading frames one by one.
      @return null
    ###
    _AddToPreload = (frame) ->
      if frame.isReady()
        return
      #else
      _preloadQueue.push(frame)
      if not _preloading
        _PreloadNext()
      return
    ###
      Clears the preloading queue and stops the preloading.
    ###
    _ResetPreload = () ->
      _preloadQueue = []
      _preloading = false
      console.log('preload queue reset')
      return
    ###
      Runner of the preloading process.
      @return null
    ###
    _PreloadNext = () ->
      if _preloadQueue.length <= 0
        _preloading = false
        return
      #else
      _preloading = true
      frame = _preloadQueue.shift()
      console.log('preloading frame', frame)
      frame.on 'load', () ->
        console.log('preloading frame complete', frame)
        setTimeout(_PreloadNext, 0)
        return
      frame.load()
      return
    ###
      Play the next frame specified by _nextFrameIndex.
      If the next frame is out of the range, the animation stops.
      @return null
    ###
    _playFrame = () ->
      if _nextFrameIndex < 0 or _nextFrameIndex >= _CountFrames()
        console.log('frame index out of range')
        _Stop()
        return
      #else
      console.log('playing next frame', _nextFrameIndex)
      _self.trigger('frame', _nextFrameIndex)
      nextFrame = _frames[_nextFrameIndex]
      
      # If the next frame is not ready, start buffering.
      if !nextFrame.isReady()
        _Buffer(nextFrame)
        return
      #else
      # Show the next frame.
      __hasFrameToHide = Boolean(_currentFrame and _currentFrame != nextFrame)
      if __hasFrameToHide
        _currentFrame.sendToBack()
      nextFrame.bringToFront()
      $_sceneElement.append(nextFrame.get$Element())
      nextFrame.trigger('show')
      if __hasFrameToHide
        $_backStageElement.append(_currentFrame.get$Element())
        _currentFrame.trigger('hide')
      _currentFrame = nextFrame
      
      if _playing and not _paused
        # Play next frame.
        _nextFrameIndex++
        _playTimer = setTimeout(_playFrame, _timePerFrame)
      return
    ##== public apis ==##
    ###
      Starts the animation from the specified index if not playing and triggers
      'play' event.
      If playing, goes to the specified index.
      If the offsetted frame is before the first frame/after the last frame,
      operation fails and returns nothing.
      @param Number newIndex
      @return null
    ###
    this.play = (newIndex) ->
      newIndex ?= 0
      maxIndex = _CountFrames() - 1
      minIndex = 0
      if newIndex < minIndex or newIndex > maxIndex
        return
      #else
      _nextFrameIndex = newIndex
      _ResetPreload()
      for index in [newIndex..maxIndex]
        _AddToPreload(_frames[index])
      # Fast play next frame.
      if _playing and not _paused
        clearTimeout(_playTimer)
      _playing = true
      _paused = false
      #_playTimer = setTimeout(_playFrame, 0)
      _playFrame()
      _self.trigger('play', newIndex)
      console.log('playing', newIndex)
      return
    #=#
    this.stop = _Stop
    ###
      Pauses the animation if playing and not paused.
      If playing but paused, does nothing.
      If not playing, does nothing.
      @return null
    ###
    this.pause = () ->
      if not _playing
        return
      #else
      if _paused
        return
      #else
      
      # Stop the animation.
      clearTimeout(_playTimer)
      _playTimer = 0
      _paused = true
      _self.trigger('pause')
      console.log('paused')
      return
    ###
      Resumes the animation if playing and paused.
      If playing but not paused, does nothing.
      If not playing, does nothing.
      @return null
    ###
    this.resume = () ->
      if not _playing
        return
      #else
      if not _paused
        return
      #else
      
      # Start the animation.
      _paused = false
      _nextFrameIndex--
      _playFrame()
      _self.trigger('resume')
      console.log('resumed')
      return
    ###
      Returns true if playing, otherwise false.
      @return Boolean
    ###
    this.isPlaying = () ->
      return _playing
    ###
      Returns true if playing and paused, otherwise false.
      @return Boolean
    ###
    this.isPaused = () ->
      return _paused
    ###
      Adds a frame to the end of the animation queue. The frame doesn't have to
      contain data, which could be fetched later and the fetched data could be
      dumped at any time to save memory.
      @param Frame|Object frame The frame to be added.
      @return Frame The managed frame object.
    ###
    this.appendFrame = (frame) ->
      if frame not instanceof FrameFactory
        frame = new FrameFactory(frame)
      if !frame
        return null
      $_backStageElement.append(frame.get$Element())
      frame.trigger('stage')
      _frames.push(frame)
      console.log('frame appended', frame)
      if _preloadBeforeStarting or _playing
        _AddToPreload(frame)
      return frame
    ###
      Returns the frame object by the given index.
      If the index is out of range, returns null.
      @param Number index
      @return Frame|null
    ###
    this.getFrameByIndex = (index) ->
      index = Number(index)
      frame = _frames[index]
      if !frame
        return null
      return frame
    ###
      Returns the index of the current frame.
      If the animation is not playing, returns -1.
      @return Number
    ###
    this.getCurrentFrameIndex = () ->
      if not _playing
        return -1
      else
        return _nextFrameIndex - 1
    #=#
    this.getFrameCount = _CountFrames
    ###
      Removes all frames in the animation queue.
      @return null
    ###
    this.clear = () ->
      _frames = []
      console.log('frames cleared')
      return
  
    return this
  #/FilmFactory
  
  @Frame = FrameFactory
  @Film = FilmFactory
)()
