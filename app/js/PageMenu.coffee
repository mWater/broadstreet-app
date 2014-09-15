# Lists pages to jump to
# ctx must be passed in as option

login = require './login'
context = require './context'

module.exports = class PageMenu extends Backbone.View
  initialize: (options) ->
    @pager = options.ctx.pager
    @options = options || {}

  events:
    "click #home" : "gotoHome"
    "click #login" : "gotoLogin"
    "click #logout" : "logout"
    "click #site_list" : "gotoSiteList"
    "click #site_map" : "gotoSiteMap"
    "click #settings" : "gotoSettings"
    "click #new_test" : "gotoNewTest"
    "click #test_list" : "gotoTestList"
    "click #survey_list" : "gotoSurveyList"
    "click #report_problem" : 'gotoProblemReport'
    "click #sensor_list" : 'gotoSensorList'

  render: ->
    @$el.html require('./PageMenu.hbs')()
    @$("#new_test").toggle(require("./pages/NewTestPage").canOpen(@options.ctx))
    @$("#survey_list").toggle(require("./pages/SurveyListPage").canOpen(@options.ctx))
    @$("#test_list").toggle(require("./pages/TestListPage").canOpen(@options.ctx))

    @$("#login").toggle(not @options.ctx.login?)
    @$("#logout").toggle(@options.ctx.login?)
    @$("#sensor_list").toggle(@options.ctx.login?)

  gotoPage: (page) ->
    while @pager.multiplePages()
      @pager.closePage()
    @pager.closePage(page)

  gotoHome: ->
    while @pager.multiplePages()
      @pager.closePage()
    @pager.closePage(require("./pages/MainPage"))

  logout: ->
    login.setLogin(null)
    
    # Update context, first stopping old one
    @options.ctx.stop()
    context.createAnonymousContext (ctx) =>
      _.extend @options.ctx, ctx
      @gotoLogin()

  gotoLogin: ->
    @gotoPage(require("./pages/LoginPage"))

  gotoSiteList: ->
    @gotoPage(require("./pages/SiteListPage"))

  gotoSiteMap: ->
    @gotoPage(require("./pages/SiteMapPage"))

  gotoSettings: ->
    @pager.openPage(require("./pages/SettingsPage"))

  gotoNewTest: ->
    @pager.openPage(require("./pages/NewTestPage"))

  gotoTestList: ->
    @gotoPage(require("./pages/TestListPage"))

  gotoSurveyList: ->
    @gotoPage(require("./pages/SurveyListPage"))

  gotoProblemReport: ->
    @pager.openPage(require("./pages/ProblemReportPage"))

  gotoSensorList: ->
    @pager.openPage(require("./pages/SensorListPage"))
