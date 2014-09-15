AppView = require("./AppView")
SlideMenu = require("./SlideMenu")
Pager = require("./Pager")
PageMenu = require("./PageMenu")
context = require './context'
login = require './login'
ProblemReporter = require './ProblemReporter'
ezlocalize = require 'ez-localize'
bowser = require 'bowser'

LoginPage = require './pages/LoginPage'
SiteMapPage = require './pages/SiteMapPage'
MainPage = require './MainPage'

AppUpdater = require './AppUpdater'

cordovaSetup = require './cordovaSetup'
consoleCapture = require './consoleCapture'

handlebars = require("hbsfy/runtime")

fastclick = require("fastclick")

startError = (err) ->
  alert("Failed to start app: " + JSON.stringify(err))

exports.start = (options = {}) ->
  _.defaults(options, { update: true, cordova: false })

  # Start recording console immediately
  consoleCapture.setup()

  # Report URL right away (cordova bug)
  console.log "Loading at: " + window.location.href

  # Setup handlebars helpers
  Swag.registerHelpers(handlebars)
  
  # Setup localizer
  localizationData = require './localizations.json'
  localizer = new ezlocalize.Localizer(localizationData, "en")
  localizer.makeGlobal(handlebars)
  localizer.restoreCurrentLocale()

  # Check browser version
  browser = bowser.browser
  unsupportedBrowser = false
  if browser.firefox
    if browser.version < 13
      unsupportedBrowser = true
  else if browser.chrome
    if browser.version < 20
      unsupportedBrowser = true
  else if browser.msie 
    if browser.version < 10
      unsupportedBrowser = true
  else if browser.ios
    # TODO Check iOS specific
  else if browser.android
    # TODO Check Android specific
  else
    unsupportedBrowser = true

  console.log(JSON.stringify(browser))

  if unsupportedBrowser
    if not confirm("Your browser is not supported. Please use Android, iOS, Chrome, Firefox 24+ or Internet Explorer 10+. Continue anyway?")
      window.location.href = "http://mwater.co"
      return

  # Check local storage
  getLocalStorageSupported = ->
    if not window.localStorage
      return false
    try
      window.localStorage.setItem("test", "test")
      window.localStorage.removeItem("test")
      return true
    catch e
      return false

  if not getLocalStorageSupported()
    alert("Your browser does not support local storage. Please turn off private browsing and reload the page.")

  # Make clicks fast in mobile
  $ => fastclick(document.body)

  # Create pager
  pager = new Pager()

  # Create slide menu
  slideMenu = new SlideMenu()

  # Create app view
  # Note: This must be done before body is fully loaded to prevent some mobile browser
  # bugs where the absolute positioning fails
  app = new AppView(slideMenu: slideMenu, pager: pager)
  $("body").append(app.$el)

  # Check if a new cache is available on page load.
  window.addEventListener "load", ((e) ->
    if not window.applicationCache?
      return

    window.applicationCache.addEventListener "updateready", ((e) ->
      if window.applicationCache.status is window.applicationCache.UPDATEREADY
        
        # Browser downloaded a new app cache.
        # Swap it in and reload the page to get the new hotness.
        window.applicationCache.swapCache()
        window.location.reload() if confirm("A new version is available. Load it now?")
      else
    
    # Manifest didn't changed. Nothing new to server.
    ), false
  ), false

  # Step 2 of setup
  step2 = ->
    withCtx = (ctx) ->
      problemReporter = ProblemReporter.register ctx.apiUrl + 'problem_reports', "//VERSION//", ->
        return ctx.login
        
      ProblemReporter.default = problemReporter

      # Set pager context
      pager.setContext(ctx)

      # Add slider sub-menus
      slideMenu.addSubmenu(pager.getContextMenu())
      slideMenu.addSubmenu(new PageMenu(ctx: ctx))

      $ -> 
        # If explicit page
        if options.initialPage == "SiteMapPage"
          pager.openPage(SiteMapPage)
        # If logged in, open main page
        else if ctx.login?
          pager.openPage(MainPage)
        else
          pager.openPage(LoginPage)

        # Determine if base app out of date
        if ctx.baseVersion and ctx.baseVersion.match(/^3\.[0-9]\./)
          pager.flash(T("Your app is out of date. Please update mWater App on Google Play"), "warning", 10000)

    # Create context
    if options.demo  
      context.createDemoContext(withCtx)
    else if login.getLogin()
      context.createLoginContext(login.getLogin(), withCtx)
    else  
      context.createAnonymousContext(withCtx)

  if options.cordova
    # Start cordova 
    cordovaSetup.setup { update: options.update },  =>
      # Get file systems
      console.log "Getting file systems..."
      window.requestFileSystem LocalFileSystem.PERSISTENT, 0, (persFs) ->
        window.requestFileSystem LocalFileSystem.TEMPORARY, 0, (tempFs) ->
          console.log "Got file systems"
          context.setupFileSystems(tempFs, persFs)
          step2()
        , startError
      , startError
    , startError
  else
    step2()

    
