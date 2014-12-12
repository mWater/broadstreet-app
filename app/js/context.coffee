### 

Creates the context used for the app

Note: There should only every be one context object. It should be modified, rather than creating a whole new object
as components like the PageMenu may be depending on it. 

Contexts have fixed members that have to be present.

db: database (LocalDb, HybridDb or RemoteDb)
imageManager: Simple or Cached Image manager
camera: Camera that has a single function: takePicture(success, error). 
  success is called with url to be passed to imageManager.addImage(url, success, error)
  error: error function to be called with unexpected errors
auth: see auth module
login: { user: <username>, groups: [<groupname>], client: <client id> }. Can be null if not logged in.
dataSync: synchronizer for data including db and site codes. Success message is to be displayed.
imageSync: synchronizer for images. Success message is to be displayed.
imageAcquirer: source of images (either camera or file selection). Has single function: acquire(success, error)
  that calls success with id of image. If not present, not available.
apiUrl: URL of API e.g. https://api.mwater.co/v3/
localizer: Localizer class, already registered as global T
updateGroupsList: function to asynchronously update login groups

stop(): must be called when context is no longer needed, or before setup of a new user

TODO fill in
TODO should any items be null of context?

###

async = require 'async'
minimongo = require 'minimongo'
loginUtils = require './login'

SimpleImageManager = require './images/SimpleImageManager'
CachedImageManager = require './images/CachedImageManager'
authModule = require './auth'
siteCodes = require './siteCodes'
syncModule = require './sync'
Camera = require './Camera'
cordovaSetup = require './cordovaSetup'
ImageUploader = require './images/ImageUploader'
ProblemReporter = require './ProblemReporter'

collectionNames = ['sites', 'forms', 'groups', 'responses', 'tests', 'source_notes', 'sensors', 'sensor_data']

apiUrl = 'https://api.mwater.co/v3/'

# TODO this is not a pretty way to set these. But it is somewhat decoupled.
temporaryFs = null
persistentFs = null

exports.setupFileSystems = (tempFs, persFs) ->
  temporaryFs = tempFs
  persistentFs = persFs

displayErrorAlert = _.debounce (msg) ->
  alert(T("Internal error") + ": " + msg)
, 5000, true

error = (err) ->
  str = if err? and err.message then err.message else err
  if typeof str != "string"
    str = JSON.stringify(str)

  if err? and err.code
    str = str + " code: #{err.code}"

  console.error("Internal Error Callback: " + str)
  displayErrorAlert(str)
  
  # Call default problem reporter if present
  if ProblemReporter.default?
    ProblemReporter.default.reportProblem(str)

# Base context
createBaseContext = ->
  camera = if Camera.hasCamera() then Camera else null

  return { 
    error: error
    apiUrl: apiUrl
    camera: camera
    version: '//VERSION//'
    baseVersion: cordovaSetup.baseVersion()
    localizer: T.localizer
    stop: ->
    # db: null
    # imageManager: null
    # auth: null 
    # login: null
    # siteCodesManager: null
    # dataSync: null
    # imageSync: null
  }

createLocalDb = (namespace, success, error) ->
  if namespace
    # Autoselect database
    minimongo.utils.autoselectLocalDb { namespace: namespace }, (localDb) =>
      success(localDb)
    , (err) =>
      console.log "Error selecting database"
      error(err)
  else
    # No local storage
    localDb = new minimongo.MemoryDb() 
    success(localDb)

# Setup database
createDb = (login, success) ->
  if login
    # Namespace includes username to be safe
    namespace = "v3.db.#{login.user}"
  else
    namespace = null

  createLocalDb namespace, (localDb) =>
    remoteDb = new minimongo.RemoteDb(apiUrl, if login then login.client else undefined)
    db = new minimongo.HybridDb(localDb, remoteDb)

    # Add collections
    async.eachSeries collectionNames, (col, callback) =>
      localDb.addCollection col, =>
        # Remote Db addCollection is synchronous
        remoteDb.addCollection(col)

        # Hybrid Db addCollection is synchronous
        db.addCollection(col)

        callback()
      , callback
    , (err) =>
      if err
        return error(err)

      # Seed local db with startup documents
      if window.seeds
        async.eachSeries _.keys(window.seeds), (col, callback) =>
          async.eachSeries window.seeds[col], (doc, callback2) =>
            localDb[col].seed doc, =>
              callback2()
            , callback2
          , callback
        , (err) =>
          if err
            return error(err)
          success(db)
      else
        success(db)
  , error

# Anonymous context for not logged in
exports.createAnonymousContext = (success) ->
  createDb null, (db) =>
    # Allow nothing
    auth = new authModule.NoneAuth()

    imageManager = new SimpleImageManager(apiUrl)

    ctx = _.extend createBaseContext(), {
      db: db
      imageManager: imageManager
      auth: auth 
      login: null
      siteCodesManager: null
      dataSync: null
      imageSync: null
    }
    success(ctx)

exports.createDemoContext = (success) ->
  createDb null, (db) =>
    # Allow caching in demo mode in non-persistent storage
    if temporaryFs
      # Silently disable upload 
      fileTransfer = new FileTransfer()
      fileTransfer.upload = (filePath, server, successCallback, errorCallback, options) =>
        successCallback()

      imageManager = new CachedImageManager(temporaryFs, apiUrl, "images", "", fileTransfer) 
    else
      imageManager = new SimpleImageManager(apiUrl)

    baseContext = createBaseContext()

    # Create image acquirer with camera and imageManager if temporaryFs and camera
    if baseContext.camera? and temporaryFs
      imageAcquirer = {
        acquire: (success, error) ->
          baseContext.camera.takePicture (url) ->
            # Add image
            imageManager.addImage url, (id) =>
              success(id)
          , (err) ->
            alert(T("Failed to take picture"))
      }
    else 
      # Use ImageUploader
      imageAcquirer = {
        acquire: (success, error) ->
          ImageUploader.acquire(apiUrl, login.client, success, error) 
      }

    # Allow everything
    auth = new authModule.AllAuth()

    # No client 
    login = { user: "demo", groups: [] }

    siteCodesManager = new siteCodes.DemoSiteCodesManager()

    ctx = _.extend baseContext, {
      db: db 
      imageManager: imageManager
      auth: auth
      login: login
      siteCodesManager: siteCodesManager
      dataSync: null
      imageSync: null
      imageAcquirer: imageAcquirer
    }
    success(ctx)

# login must contain user, client, email members. "user" is username. 
# login can be obtained by posting to api /clients
exports.createLoginContext = (login, success) ->
  createDb login, (db) =>
    if persistentFs
      fileTransfer = new FileTransfer()
      imageManager = new CachedImageManager(persistentFs, apiUrl, "Android/data/org.broadst.ebola/images", login.client, fileTransfer)  
    else
      imageManager = new SimpleImageManager(apiUrl)

    auth = new authModule.UserAuth(login.user, login.groups)
    siteCodesManager = new siteCodes.SiteCodesManager(apiUrl + "site_codes?client=#{login.client}")
    dataSync = new syncModule.DataSync(db, siteCodesManager)
    imageSync = new syncModule.ImageSync(imageManager)

    # Start synchronizing
    dataSync.start(30*1000)  # Every 30 seconds
    imageSync.start(30*1000)  # Every 30 seconds

    # Perform sync immediately
    dataSync.perform()
    imageSync.perform()

    stop = ->
      dataSync.stop()
      imageSync.stop()

    baseContext = createBaseContext()

    # Create image acquirer with camera and imageManager if persistentFs and camera
    if baseContext.camera? and persistentFs
      imageAcquirer = {
        acquire: (success, error) ->
          baseContext.camera.takePicture (url) ->
            # Add image
            imageManager.addImage url, (id) =>
              success(id)
          , (err) ->
            alert(T("Failed to take picture"))
      }
    else 
      # Use ImageUploader
      imageAcquirer = {
        acquire: (success, error) ->
          ImageUploader.acquire(apiUrl, login.client, success, error) 
      }

    # Add function to asynchronously update groups list 
    updateGroupsList = () ->
      $.getJSON(apiUrl + "clients/" + login.client).done (response) =>
        # Update login groups and save
        login.groups = response.groups
        loginUtils.setLogin(login)

    # Always update immediately
    updateGroupsList()

    ctx = _.extend baseContext, {
      db: db 
      imageManager: imageManager
      auth: auth
      login: login
      siteCodesManager: siteCodesManager
      dataSync: dataSync
      imageSync: imageSync
      stop: stop
      imageAcquirer: imageAcquirer
      updateGroupsList: updateGroupsList
    }
    success(ctx)
