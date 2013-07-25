# Continue an existing survey
Page = require "../Page"
SurveyPage = require "./SurveyPage"
NewSurveyPage = require './NewSurveyPage'

class ExistingSurveyPage extends Page
  @canOpen: (ctx) -> ctx.auth.update("responses") 

  events: 
    "click .response" : "openResponse"

  create: ->
    @$el.html templates['pages/ExistingSurveyPage']()
    @setTitle "Select Survey"

    @setupButtonBar [ { icon: "plus.png", click: => @addSurvey() } ]

  activate: ->
    # Query database for recent, completed surveys
    recent = new Date()
    recent.setDate(recent.getDate() - 30)

    @db.responses.find({ completed: { $gt:recent.toISOString() }, user: @login.user }, {sort:[['started','desc']]}).fetch (responses) =>
      @$("#recent_table").html templates['pages/ExistingSurveyPage_items'](responses:responses)

      # Fill in survey names
      for resp in responses
        @db.forms.findOne { code:resp.type }, { mode: "local" }, (form) =>
          @$("#name_"+resp._id).text(if form then form.name else "???")

    @db.responses.find({ completed: null, user: @login.user }, {sort:[['started','desc']]}).fetch (responses) =>
      @$("#incomplete_table").html templates['pages/ExistingSurveyPage_items'](responses:responses)

      # Fill in survey names
      for resp in responses
        @db.forms.findOne { code:resp.type }, { mode: "local" }, (form) =>
          @$("#name_"+resp._id).text(if form then form.name else "???")

  openResponse: (ev) ->
    responseId = ev.currentTarget.id
    @pager.closePage(SurveyPage, { _id: responseId})

  addSurvey: ->
    @pager.openPage(NewSurveyPage)

module.exports = ExistingSurveyPage