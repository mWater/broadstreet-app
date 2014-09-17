Page = require "../Page"
SitePage = require './SitePage'
SitesLayer = require '../map/SitesLayer'
SiteLayerCreators = require '../map/SiteLayerCreators'
LocationDisplay = require '../map/LocationDisplay'
LocationFinder = require '../LocationFinder'
BaseLayers = require '../map/BaseLayers'
offlineMap = require 'offline-leaflet-map'
CacheProgressControl = require '../map/CacheProgressControl'
GeoJSON = require '../GeoJSON'
LocationSetter = require('../map/LocationSetter')

# Map of sites. Options include:
# initialGeo: Geometry to zoom to. Point only supported.
# onSelect - function to call with site doc when selected
# filterSiteTypes: list of site types to include. null for all
class SiteMapPage extends Page
  events:
    "click #goto_my_location": "gotoMyLocation"
    "click #new_site": "addSite"
    "click #new_survey": ->
      # defer to Allow menu to close first
      _.defer => @pager.openPage(require("./NewSurveyPage"))
    "click #new_test": -> 
      # defer to Allow menu to close first
      _.defer => @pager.openPage(require("./NewTestPage"))

  activate: ->
    # Create filter of site types
    @siteTypesFilter = {}
    if @options.filterSiteTypes
      @siteTypesFilter.type = { $in: @options.filterSiteTypes }

    @setTitle T("Site Map")

    @deactivated = false

    @$el.html require('./SiteMapPage.hbs')()

    @resizeMap()

    # Update groups
    if @updateGroupsList
      @updateGroupsList()

    # Wrap onSelect to close page
    if @options.onSelect
      @onSelect = (site) =>
        @pager.closePage()
        @options.onSelect(site)

    # If initialGeo specified, use it
    if @options.initialGeo and @options.initialGeo.type == "Point"
      @createMap(L.GeoJSON.coordsToLatLng(@options.initialGeo.coordinates), 15)
      return

    # Get current position
    currentLatLng = null
    locationFinder = new LocationFinder()
    locationFinder.getLocation (pos) =>
      currentLatLng = new L.LatLng(pos.coords.latitude, pos.coords.longitude)

      @cacheNearbySites(pos)
    , ->
      # Do nothing on error
      currentLatLng = null

    # If saved view
    if window.localStorage['SiteMapPage.lastView']
      lastView = JSON.parse(window.localStorage['SiteMapPage.lastView'])
      @scope = lastView.scope
      @createMap(lastView.center, lastView.zoom)
      return

    # Wait very short time for location
    setTimeout =>
      if not @deactivated
        # If no location, create map with no location
        if currentLatLng
          @createMap(currentLatLng, 14)
        else
          @createMap()
    , 500

  deactivate: ->
    if @cacheProgressControl 
      @cacheProgressControl.cancel()
      
    $(window).off('resize', @resizeMap)
    if @locationDisplay
      @locationDisplay.stop()

    # Destroy map
    if @map
      @map.remove()
      @map = null
    @deactivated = true

  # Since most uses use the map only, we need to cache local sites to the database.
  # This is done by simply querying them
  cacheNearbySites: (pos) ->
    selector = geo: 
      $near: { $geometry: GeoJSON.posToPoint(pos) }

    # Query database for near sources
    @db.sites.find(selector, { limit: 200 }).fetch (sites) =>
      # Just cache them
      return
    , @error

  # Create a map with center and zoom
  createMap: (center, zoom) ->
    # Fix leaflet image path
    L.Icon.Default.imagePath = "img/leaflet"

    # Setup button bars (now that we know the scope)
    @configureButtonBars()

    options = {}
    # See issue https://github.com/mWater/app-v3/issues/103
    if navigator.userAgent.toLowerCase().indexOf('android 4.1.1') != -1 or navigator.userAgent.toLowerCase().indexOf('android 4.0.4') != -1
      options.touchZoom = false
      options.fadeAnimation = false

    options.minZoom = 2

    @map = L.map(this.$("#map")[0], options)
    L.control.scale(imperial:false).addTo(@map)
    @resizeMap()

    # Recalculate on resize
    $(window).on('resize', @resizeMap)

    onReady = () =>
      # If not already deactivated
      if @map and not @deactivated
        @osmLayer.addTo(@map)
        @configureButtonBars()

    onError = (errorType, errorData) =>
      if errorType == "COULD_NOT_CREATE_DB"
        console.log("Could not created DB.")
      else
        if @cacheProgressControl?
          if not @cacheProgressControl.cancelling
            @cacheProgressControl.cancel();
            
        if errorType == "NETWORK_ERROR"
          errorMsg = errorType + ":" + errorData
          console.log(errorMsg)
          @pager.flash(T("Network error. Unable to save image."), "danger")
        else if errorType == "ZOOM_LEVEL_TOO_LOW"
          alert(T("You are trying to save too large of a region of the map. Please zoom in further."))
        else if errorType == "SYSTEM_BUSY"
          alert(T("System is busy"))
        else
          console.log("#{errorType}:#{errorData}")
          @pager.flash(errorType, "danger")

    # Setup base layers
    @osmLayer = BaseLayers.createOSMLayer(onReady, onError)

    # Setup initial zoom
    if center
      @map.setView(center, zoom)
    else
      # Zoom to Monrovia, Liberia
      @map.setView(new L.LatLng(6.3376,-10.7275), 12)

    if @options.setLocation
      new LocationSetter(@map, (newLoc) =>
        @pager.closePage()
        @options.setLocation(newLoc)
      )

    # Add layers
    siteLayerCreator = new SiteLayerCreators.SimpleSitesLayerCreator @ctx, (_id) =>
      @pager.openPage(SitePage, { _id: _id, onSelect: @onSelect })

    # Calculate site filter
    filter = @calculateSiteFilter()
    @sitesLayer = new SitesLayer(siteLayerCreator, @db.sites, filter).addTo(@map)

    # TODO remove legend
    # # Add legend
    # @legend = L.control({position: 'bottomright'});
    # @legend.onAdd = (map) ->
    #   return siteLayerCreator.createLegend()
    # @legend.addTo(@map)

    # Add My Location control
    @myLocation = L.control({position: 'topright'})
    @myLocation.onAdd = (map) ->
      html = '''
      <img id="goto_my_location" class="image-control" src="img/goto-my-location.png">
      '''
      return $(html).get(0)
    @myLocation.addTo(@map)

    # Save view
    @map.on 'moveend', @saveView

    # Setup location display
    @locationDisplay = new LocationDisplay(@map)

  # Filter the sites by all, groups, or user
  updateSiteScope: (scope) => 
    @scope = scope

    # Update Map
    @sitesLayer.setFilter(@calculateSiteFilter())
    @sitesLayer.update()

    # Update UI
    @configureButtonBars()

    # Persist the view
    @saveView()

  # Calculate filter to use for sites
  calculateSiteFilter: ->
    option = _.findWhere(@getSiteScopeOptions(), { type: @scope })
    if option
      return _.extend(option.value, @siteTypesFilter) 
    else
      return @siteTypesFilter

  saveView: => 
    if @deactivated or not @map
      return
      
    window.localStorage['SiteMapPage.lastView'] = JSON.stringify({
      center: @map.getCenter() 
      zoom: @map.getZoom()
      scope: @scope
    })

  gotoMyLocation: ->
    # Goes to current location
    locationHasBeenSetAtLeastOnce = false
    locationFinder = new LocationFinder()
    locationFinder.getLocation (pos) =>
      if not @deactivated
        latLng = new L.LatLng(pos.coords.latitude, pos.coords.longitude)
        # if the view has been set at least once (by a lower accuracy location)
        if locationHasBeenSetAtLeastOnce
          # do not set the view again if the higher accuracy location is inside the current view
          # the idea is to avoid setting the map view many times
          if @map.getBounds().contains(latLng)
            return

        zoom = @map.getZoom()
        @map.setView(latLng, if zoom > 15 then zoom else 15)
        locationHasBeenSetAtLeastOnce = true
    , =>
      if not @deactivated
        @pager.flash(T("Unable to determine location"), "warning")


  # Configure gear menu 
  configureButtonBars: ->
    # Get options for site menu
    options = @getSiteScopeOptions()

    # If current option is invalid, set to first one
    if not (@scope in _.pluck(options, "type"))
      @scope = options[0].type

    # Create a dropdown menu using the Site Scope Options
    menu = _.map options, (scope) =>
      text: scope.display
      id: "site_scope_" + scope.type
      click: => @updateSiteScope(scope.type)
      checked: @scope == scope.type

    if @osmLayer? and @osmLayer.useDB()
      menu.push { separator: true }
      menu.push {
        text: T("Make Available Offline")
        click: => @cacheTiles()
      }

    @$("#gear_menu").html(require("./SiteMapPage_gearmenu.hbs")(menu: menu))

    @setupButtonBar [
      { icon: "buttonbar-gear.png", menu: menu }
      { text: T("List"), click: => @pager.closePage(require("./SiteListPage"), {onSelect: @options.onSelect, filterSiteTypes: @options.filterSiteTypes})}  
    ]

  # Options for the dropdown menu
  getSiteScopeOptions: =>
    options = [{ display: T("All Sites"), type: "all", value: {} }]
    # Only show groups choice if user has groups
    if @login?
      if @login.groups.length > 0
        options.push { 
          display: T("Only My Groups")
          type: "groups"
          value: { "created.for": { $in: @login.groups } }
        }

      if @login.user?
        options.push { display: T("Only Mine"), type: "user", value: { "created.by": @login.user } }
    return options

  addSite: ->
    # defer to Allow menu to close first
    _.defer => 
      @pager.openPage(require("./NewSitePage"), {onSelect: @onSelect, filterSiteTypes: @options.filterSiteTypes})

  resizeMap: =>
    # TODO why does this prevent crashes?
    if not @map
      return

    # Calculate map height
    mapHeight = $("html").height() - 50 - 50
    $("#map").css("height", mapHeight + "px")
    @map.invalidateSize()

  cachingCompleted: ->
    @cacheProgressControl = null

  # Caches tiles and makes them available offline
  cacheTiles: ->
    if @cacheProgressControl?
      return
    maxNbTiles = 10000

    nbTiles = @osmLayer.calculateNbTiles()
    # nbTiles of -1 means an error occurred
    if nbTiles == -1
      return
    console.log("Would be saving: " + nbTiles + " tiles")

    zoomLimit = @map.getMaxZoom()
    console.log("Trying to save: " + nbTiles)

    minZoomLimit = 15
    while zoomLimit > minZoomLimit && nbTiles > maxNbTiles
      nbTiles /= 4
      zoomLimit--
      console.log("Lowered zoom level to: " + zoomLimit)
      console.log("Would now save: " + nbTiles)

    if nbTiles < maxNbTiles
      if not confirm T("Download approximately {0} MB of map data and make available offline?", Math.ceil(nbTiles*0.01))
        return

      # Add progress/cancel display
      @cacheProgressControl = new CacheProgressControl(@map, @osmLayer, this)

      # Save the tiles
      @cacheProgressControl.saveTiles(zoomLimit)

      # Cache sites as well 
      @sitesLayer.cacheSites (sites) ->
        # Do nothing with returned sites
        console.log "#{sites.length} sites cached"
      , @error
    else
      alert(T("You are trying to save too large of a region of the map. Please zoom in further."))


setupMapTiles = ->
  mapquestUrl = 'http://{s}.mqcdn.com/tiles/1.0.0/osm/{z}/{x}/{y}.png'
  subDomains = ['otile1','otile2','otile3','otile4']
  mapquestAttrib = 'Data, imagery and map information provided by <a href="http://open.mapquest.co.uk" target="_blank">MapQuest</a>, <a href="http://www.openstreetmap.org/" target="_blank">OpenStreetMap</a> and contributors.'
  return new L.TileLayer(mapquestUrl, {maxZoom: 18, attribution: mapquestAttrib, subdomains: subDomains})


module.exports = SiteMapPage
