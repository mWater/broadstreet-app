Page = require "../Page"
mwaterforms = require 'mwater-forms'
ResponseModel = require('mwater-common').ResponseModel
ImagePage = require './ImagePage'
SiteListPage = require './SiteListPage'
SiteMapPage = require './SiteMapPage'
GeoJSON = require '../GeoJSON'
SurveyListPage = require './SurveyListPage'

class SurveyPage extends Page
  @canOpen: (ctx) -> ctx.auth.update("responses")

  create: -> 
    # Set default locale
    @formLocale = @localizer.locale

    @render()

  displayFormView: ->
    # Close if no response (can happen on deleted response on server)
    if not @response
      return
      
    # Remove existing survey control
    if @formView?
      @formView.remove()

    data = {
      response: @response
      name: mwaterforms.formUtils.localizeString(@form.design.name, @formLocale)
      canRedraft: @responseModel.canRedraft()
      locales: @form.design.locales
    }

    @$el.html require('./SurveyPage.hbs')(data)

    # Set locale dropdown
    @$("#locale").val(@formLocale)

    # Check if redraftable
    if @response.status == "draft" or @response.status == "rejected"
      # Load response data to model
      model = new Backbone.Model()
      model.set(_.cloneDeep(@response.data))

      # Create context for forms            
      ctx = {
        displayImage: (options) =>
          @pager.openPage(ImagePage, { id: options.id, onRemove: options.remove, onSetCover: options.setCover })
        imageManager: @ctx.imageManager
        imageAcquirer: @ctx.imageAcquirer
        selectSite: (siteTypes, success) =>
          @pager.openPage SiteListPage, { filterSiteTypes: siteTypes, onSelect: (source)=> success(source.code) }
        getSite: (siteCode, success, error) =>
          @db.sites.findOne { code: siteCode }, (site) =>
            if site
              success(site)
          , error
        displayMap: (location, setLocation) =>
          options = {}
          options.setLocation = setLocation
          if location?
            options.initialGeo = { type: 'Point', coordinates: [location.longitude, location.latitude] }
          @pager.openPage require("./SiteMapPage"), options
        stickyStorage: {
          get: (key) =>
            str = window.localStorage["stickyStorage:" + @form._id + ":" +@login.user + ":" + key]
            if str? and str.length > 0
              return JSON.parse(str)
          set: (key, value) =>
            window.localStorage["stickyStorage:" + @form._id + ":" +@login.user + ":" + key] = JSON.stringify(value)
        }
      }

      # Check schema version
      schema = @form.design._schema or 1
      if schema > mwaterforms.schemaVersion
        alert(T("Please update Broadstreet App to use this form"))
        return @pager.closePage()

      if schema < mwaterforms.minSchemaVersion
        alert(T("This form is out of date and cannot be opened"))
        return @pager.closePage()

      # Create compiler
      compiler = new mwaterforms.FormCompiler(model: model, locale: @formLocale, ctx: ctx)

      @formView = compiler.compileForm(@form.design, ctx).render()
      
      # Listen to events
      @listenTo @formView, 'change', @save
      @listenTo @formView, 'complete', @completed
      @listenTo @formView, 'close', @close
      @listenTo @formView, 'discard', @removeResponse

      # The mode parameter tells us that a new response has just been created for that page
      if @options.mode == "new"
        # When it's the case, we want to search for other drafts of that form
        @db.responses.find({ form: @form._id, _id: { $ne: @response._id }, status: 'draft', user: @login.user }, {sort:[['startedOn','desc']], limit: 10}).fetch (responses) =>
          # If we do find other draft(s), we will prompt the user with an alert
          if responses.length > 0
            # If there is only one draft, we get the _id so we can load that response
            if responses.length == 1
              @otherSurveyId = responses[0]._id
              @$("#alarm_text").text(T("A draft already exists for this survey"))
              @$("#go_to_existing_draft_btn").text(T("Use Existing Draft"))
            # If there are many drafts, we want to bring the user back to the survey list so he can select one.
            else
              @$("#alarm_text").text(T("Several drafts already exists for this survey"))
              @$("#go_to_existing_draft_btn").text(T("Go to Drafts"))

            # Animating the alarm
            alarmDiv = @$("#alarm_div")
            alarmDiv.show()
            setTimeout =>
              alarmDiv.slideUp(400, => alarmDiv.remove())
            , 10 * 1000

    else
      @formView = new Backbone.View() # TODO?
      if @response.status == "final"
        @formView.$el.html("<em>" + T("Response has been finalized and cannot be edited") + "</em>") # TODO
      else
        @formView.$el.html("<em>" + T("Response is pending approval") + "</em>") # TODO

    # Add form view
    @$("#contents").append(@formView.el)

    if not @responseModel.canRedraft() or @response.status in ['draft', 'rejected']
      @$("#edit_button").hide()

  render: ->
    @setTitle T("Survey")

    # Get response
    @db.responses.findOne {_id: @options._id}, (response) =>
      # Ignore if page has been destroyed
      return if @destroyed

      if not response
        alert(T("Survey not found"))
        return @pager.closePage()

      @response = response

      # Get form
      @db.forms.findOne { _id: response.form }, (form) =>
        if not form
          alert T("Survey form not found")
          @pager.closePage()
          return

        @form = form

        @responseModel = new ResponseModel(response, form, @login.user, @login.groups)

        if @responseModel.canDelete()
          @setupContextMenu [ { glyph: 'remove', text: T("Delete Survey"), click: => @removeResponse() } ]
        else 
          @setupContextMenu [ ]

        # Render survey page
        @displayFormView()
      , @error
    , @error


  events:
    "click #edit_button" : "edit"
    "change #locale" : "changeLocale"
    "click #go_to_existing_draft_btn" : "gotoExistingDraft"

  gotoExistingDraft: ->
    # The user has clicked on the alarm telling him that other drafts exist for that form
    @useExistingDraft = true
    @db.responses.remove @response._id, =>
      if @otherSurveyId?
        # Load the draft
        @pager.closePage(SurveyPage, {_id: @otherSurveyId})
      else
        # Go back to the list of drafts
        @returnToSurveyList()
    , @error


  changeLocale: ->
    # Save to be safe
    @save()

    @formLocale = @$("#locale").val()
    @displayFormView()

  activate: ->
    # Do not reload as form may have launched another page
    # and needs to keep its state

  destroy: ->
    # Let know that saved if closed incompleted
    if @response and @response.status == "draft" and not @useExistingDraft
      @pager.flash T("Survey saved as draft.")

    # Remove survey control
    if @formView?
      @formView.remove()

  edit: ->
    # Redraft
    @responseModel.draft()
    @db.responses.upsert @response, => 
      @render()
    , @error

  save: =>
    if @formView.save
      # Save to db
      @response.data = @formView.save()
      @db.responses.upsert @response, =>
        return
      , @error

  close: ->
    @save()
    @returnHome()

  returnHome: ->
    @pager.closePage()

  returnToSurveyList: ->
    # Here to solve circularity bug
    SurveyListPage = require './SurveyListPage'
    if @pager.getParentPage() instanceof SurveyListPage
      @pager.closePage()
    else
      @pager.closePage(SurveyListPage)

  completed: =>
    # Submit
    @response.data = @formView.save()
    @responseModel.submit()

    @db.responses.upsert @response, =>
      @returnHome()

      @pager.flash T("Survey completed successfully"), "success"
    , @error

  removeResponse: ->
    if @auth.remove("responses", @response) and confirm(T("Permanently delete survey?"))
      @db.responses.remove @response._id, =>
        @response = null
        @pager.closePage()
        @pager.flash T("Survey deleted"), "warning"
      , @error

module.exports = SurveyPage
