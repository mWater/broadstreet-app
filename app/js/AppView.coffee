class AppView extends Backbone.View
  className: 'appview'
  constructor: (opts) ->
    super(opts)
    @slideMenu = opts.slideMenu
    @pager = opts.pager

    # Listen to page change events
    @listenTo @pager, 'change', @pageChanged

    # Add mobile behavior (TODO remove this someday when legacy forms are gone)
    require('./mobile-behavior').setup(@$el)
    
    @render()

    # Add button bar
    @$("#navbar_buttons").append(@pager.getButtonBar().el)

  events:
    'click #navbar_slidemenu_button': 'toggleSlideMenu'
    'click #navbar_back_button': 'back'
    'click #appview_content': 'hideSlideMenu'

  render: ->  	
    @$el.html require('./AppView.hbs')()
    @$el.append @slideMenu.el
    @$('#appview_content').append @pager.el
    this

  toggleSlideMenu: -> @slideMenu.toggle()
  hideSlideMenu: -> @slideMenu.hide()

  pageChanged: ->
    # Remove loading if present
    @$("#appview_loading").remove()

    # Set title and back button
    @$("#navbar_back_button").toggle(@pager.multiplePages())
    title = @pager.getTitle()
    # Ignore title TODO
    @$("#navbar_title").text(T("Broadstreet"))

    # # Show brand logo if no title
    # @$("#brand_logo").toggle(not title)
    # @$("#navbar_title").toggle(title)

    # Hide slide menu if multiple pages
    @$("#navbar_slidemenu_button").toggle(not @pager.multiplePages())

  back: ->
    @slideMenu.hide()
    @pager.closePage()
    return false
 
module.exports = AppView    
    