Generic Javascript Film Player
================================
Version 1.0.0.

This library supports "video/film playing" by switching frames in and out for you.
This library only depends on jQuery.

How to use
--------------------------------

First, create a `Film` instance.

```CoffeeScript
film = new Film
	# The element that's going to contain the frames and the "backstage".
	# For best results, the target should have position "relative", "absolute" or "fixed".
	target: document.body
	# How fast the film is going to be played.
	# At the moment this can only be set when creating the film.
	fps: 30
	# Set this to true to start preloading before the film starts playing.
	preloadBeforeStarting: false

# Observable events of the film
# play (frameIndex): when the film has started playing from frameIndex.
# pause (): when the film has been paused.
# resume (): when the film has been resumed.
# stop (): when the film has been stopped.
```

Doing so would create a "backstage" element inside `target` for holding frames.

Now it's time to add frames.

```CoffeeScript
someFrame = new Frame
	constructor: () ->
		# The constructor function is called when the frame is added to the film.
		# this.getElement() returns the frame element.
		# this.get$Element() returns a jQuery wrapped frame element.
		# Now it's time to do the data-irrelevant setup of the frame element.
		# this.set(key, value) and this.get(key) can be used to save and retrieve data and references.
		# If the data of the frame is ready, call this.ready() to mark this frame as ready.
		return
	loader: () ->
		# The loader function is called when the frame is being preloaded.
		# It is the loader's job to fetch the data and finish the final touches of the frame.
		# Remember to call this.ready() when the frame is ready.
		# The loader could be called multiple times before the frame is ready, so make sure to manage the loading state.
		return
film.appendFrame someFrame

# Observable events of the frame
# stage (): when the frame has been added to the backstage of the film.
# show (): when the frame has been brought to the scene from the backstage and is visible to the viewer.
# hide (): when the frame has been brought to the backstage and is no longer visible.
# load (): when the frame is ready.
```

If `preloadBeforeStarting` was set to `true` for the film, appended frames will be queued up for preloading right away.
Otherwise preloading only happens after the film has started playing.

Now let's play the film!

```CoffeeScript
film.play()
# Other publicly available APIs of the film include:
# film.play(startingFrameIndex)
# film.pause()
# film.resume()
# film.stop()
# film.isPlaying()
# film.isPaused()
# film.getFrameByIndex(index)
# film.getCurrentFrameIndex()
# film.getFrameCount()
# film.clear()
```

For more details please refer to the documentation in the source code.

Features to be added
--------------------------------
* Frame data dumping - ask played frames to dump their data to free up memory.
* Lazy preloading - only preload frames that are about to be played.
* `beforeShow` and `beforeHide` - more events allowing the frames to do more.
