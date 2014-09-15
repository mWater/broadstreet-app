Page = require "../Page"
context = require '../context'
MainPage = require './MainPage'
utils = require './utils'
SignupPage = require './SignupPage'

module.exports = class LoginPage extends Page
  events:
    'click #signup_button' : 'signupClicked'
    'submit #form_login' : 'loginClicked'
    'click #demo_button' : 'demoClicked'
    "change #locale": "setLocale"

  activate: ->
    @setTitle ""
    @render()

  render: ->
    @$el.html require('./LoginPage.hbs')(locales: @localizer.getLocales())

    # Select current locale
    @$("#locale").val(@localizer.locale)

  setLocale: ->
    @localizer.locale = @$("#locale").val()
    @localizer.saveCurrentLocale()
    @render()

  signupClicked: ->
    # Open signup form
    @pager.openPage(SignupPage)

  login: (username, password) ->
    success = =>
      @pager.closeAllPages(MainPage)
      @pager.flash T("Login as {0} successful", username), "success"

    error = =>
      $("#login_button").removeAttr('disabled')

    # Disable button temporarily
    $("#login_button").attr("disabled", "disabled")

    utils.login(username, password, @ctx, success, error)

  loginClicked: (e) ->
    # Prevent actual submit
    e.preventDefault()

    username = @$("#login_username").val().trim()
    password = @$("#login_password").val().trim()

    @login(username, password)
    return

  demoClicked: ->
    # Update context, first stopping old one
    @ctx.stop()
    context.createDemoContext (ctx) =>
      _.extend @ctx, ctx

      @pager.closePage(MainPage)
      @pager.flash T("Running in Demo mode. No changes will be saved"), "warning", 10000
