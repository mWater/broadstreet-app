Page = require("../Page")
NewSurveyPage = require("./NewSurveyPage")
SurveyListPage = require("./SurveyListPage")
TestListPage = require("./TestListPage")
NewTestPage = require("./NewTestPage")
NewSitePage = require("./NewSitePage")
SiteListPage = require("./SiteListPage")
SiteMapPage = require("./SiteMapPage")

class MainPage extends Page
  events:
    "click #report_possible_case" : "reportPossibleCase"
    "click #report_death" : "reportDeath"
    "click #report_need" : "reportNeed"

  activate: ->
    @setTitle ""

    # Rerender on error/success of sync
    if @dataSync?
      @listenTo @dataSync, "success error", =>
        @render()

    if @imageSync?
      @listenTo @imageSync, "success error", =>
        @render()

    # Update groups
    if @updateGroupsList
      @updateGroupsList()

    @render()

  deactivate: ->
    # Stop listening to events
    if @dataSync?
      @stopListening @dataSync
    if @imageSync?
      @stopListening @imageSync

  render: ->
    # # Determine if base app out of date
    # if @baseVersion and @baseVersion.match(/^3\.[0-3]/)
    #   outdated = true
    outdated = false

    # Determine data sync status
    if @dataSync?
      if @dataSync.inProgress
        dataSyncText = T("In progress...")
        dataSyncClass = "muted"
      else if @dataSync.lastError
        # Check if jQuery ajax error
        if @dataSync.lastError.status?
          # If connection error
          if @dataSync.lastError.status == 0
            dataSyncText = T("No connection")
            dataSyncClass = "warning"
          else if @dataSync.lastError.status >= 500
            dataSyncText = T("Server error")
            dataSyncClass = "danger"
          else if @dataSync.lastError.status >= 400
            dataSyncText = T("Upload error")
            dataSyncClass = "danger"
        else
          dataSyncText = @dataSync.lastError
          dataSyncClass = "danger"
      else
        dataSyncText = T("Complete")
        dataSyncClass = "success"

    data = {
      login: @login
      version: @version
      baseVersion: @baseVersion
      lastSyncDate: @dataSync.lastSuccessDate if @dataSync?
      imagesRemaining: @imageSync.lastSuccessMessage if @imageSync?
      dataSyncText: dataSyncText
      dataSyncClass: dataSyncClass
      outdated: outdated
    }

    @$el.html require('./MainPage.hbs')(data)

    # Display upserts pending
    if @dataSync
      @dataSync.numUpsertsPending (num) =>
        if num > 0
          $("#upserts_pending").html(T("<b>{0} records to upload</b>", num))
        else
          $("#upserts_pending").html("")
      , @error

    # Display images pending
    if @imageManager? and @imageManager.numPendingImages?
      @imageManager.numPendingImages (num) =>
        if num > 0
          $("#images_pending").html(T("<b>{0} images to upload</b>", num))
        else
          $("#images_pending").html("")
      , @error


  reportPossibleCase: -> startSurvey("dd909cb39f544ff7b5cdce6951b6a63f")
  reportDeath: -> startSurvey("dd909cb39f544ff7b5cdce6951b6a63f")
  reportNeed: -> startSurvey("dd909cb39f544ff7b5cdce6951b6a63f")


  startSurvey: (formId) ->
    form = _.findWhere(@forms, { _id: formId })
    if not form
      @error(T("Form not found"))
      return

    response = {}
    responseModel = new ResponseModel(response, form, @login.user, @login.groups) 
    responseModel.draft()

    @db.responses.upsert response, (response) =>
      @pager.closePage(SurveyPage, {_id: response._id, mode: "new"})
    , @error
    
module.exports = MainPage