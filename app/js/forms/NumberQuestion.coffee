Question = require('./form-controls').Question

module.exports = Question.extend
  renderAnswer: (answerEl) ->
    answerEl.html _.template("<input class=\"form-control\" type=\"number\" <% if (options.decimal) {%>step=\"any\"<%}%> />", this)
    answerEl.find("input").val @model.get(@id)

  events:
    change: "changed"

  validateInternal: ->
    val = @$("input").val()
    if @options.decimal and val.length > 0
      if isNaN(parseFloat(val))
        return "Invalid decimal number"
    else if val.length > 0
      if not val.match(/^-?\d+$/)
        return "Invalid integer number"
    return null

  changed: ->
    val = parseFloat(@$("input").val())
    if isNaN(val)
      val = null
    @model.set @id, val 
