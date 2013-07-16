# Objects that help with synchronizing with the server

# Class which repeats an operation every n ms or when called
# Puts mutex on action
exports.Repeater = class Repeater 
  constructor: (action) ->
    @action = action
    @running = false
    @inprogress = false

  start: (every) ->
    @every = every
    @running = true
    setTimeout @performRepeat, every

  stop: ->
    @running = false

  performRepeat: =>
    if not @running
      return

    success = (message) =>
      @inprogress = false
      if @running
        setTimeout @performRepeat, @every
      @lastSuccessDate = new Date()
      @lastSuccessMessage = message
      @lastError = undefined

    error = (err) =>
      @inprogress = false
      if @running
        setTimeout @performRepeat, @every
      @lastError = err

    @inprogress = true
    @action(success, error)

  perform: (success, error) ->
    success2 = (message) =>
      @inprogress = false
      @lastSuccessMessage = message
      @lastSuccessDate = new Date()
      @lastError = undefined
      success(message) if success?

    error2 = (err) =>
      @inprogress = false
      @lastError = err
      error(err) if error?

    @inprogress = true
    @action(success2, error2)

exports.Synchronizer = class Synchronizer
  constructor: (hybridDb, imageManager, sourceCodesManager) ->
    @hybridDb = hybridDb
    @imageManager = imageManager
    @sourceCodesManager = sourceCodesManager

    @repeater = new Repeater(@_sync)

  start: (every) -> @repeater.start(every)
  stop: -> @repeater.stop()

  sync: (success, error) ->
    @repeater.perform(success, error)

  _sync: (success, error) =>
    successHybrid = =>
      successSourceCodes = =>
        progress = =>
          # Do nothing with progress
        successImages = (numImagesRemaining) =>
          success(if numImagesRemaining then "#{numImagesRemaining} images left" else "complete")
        @imageManager.upload progress, successImages, error
      @sourceCodesManager.replenishCodes 5, successSourceCodes, error
    @hybridDb.upload successHybrid, error

# Synchronizer that does nothing and always returns success
exports.DemoSynchronizer = class DemoSynchronizer
  start: -> 
  stop: -> 
  sync: (success, error) ->
    success("complete")
