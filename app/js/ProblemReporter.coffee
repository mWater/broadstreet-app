# Reports problems (crashes) to a server. Catches window.onerror to catch unhandled
# exceptions. Set ProblemReporter.default to the problem reporter that should be globally
# available, if desired.
consoleCapture = require './consoleCapture'

ProblemReporter = (url, version, getLogin) ->
  @reportProblem = (desc, success, error) =>
    console.log "Reporting problem..."
    device = "Unknown"
    try 
      device = JSON.stringify(window.device)
    catch ex
      console.error "Exception getting device"

    # Create log string
    log = consoleCapture.getHistory().join("\r\n")

    report =
      version: version
      user_agent: navigator.userAgent
      log: log
      desc: desc
      device: device
      url: window.location.href
      date: new Date().toISOString()

    login = getLogin()
    _.defaults report, login

    # Hide client details
    if report.client
      report.client = report.client.substr(0,24) + "..."

    postUrl = if (login and login.client) then url + "?client=" + login.client else url
    req = $.post url, report
    req.done =>
      if success?
        success()
    req.fail =>
      if error?
        error()

  # Capture console
  consoleCapture.setup()

  # Don't overload the server with errors
  @reportProblem = _.debounce(@reportProblem, 30000, true)
  
  # Capture window.onerror
  oldWindowOnError = window.onerror

  # Prevent recursion
  reportingError = false

  handleOnError = (message, file, line, column, errorObj) =>
    reportingError = true

    # Get text of message
    text = "window.onerror: #{message} at #{file}:#{line}:#{column}"

    # Polite message for Safari QuotaExceededError
    if text.match(/QuotaExceededError/)
      alert T("Your browser is refusing to store data for offline use. Please check that not in private browsing mode and reload page.")
    else
      # Put up alert instead of old action
      alert T("Internal Error") + "\n" + text

    # Add stack
    if errorObj?
      text = text + "\n" + errorObj.stack

    if window.location.href.match(/127\.0\.0\.1/)
      console.log 'Ignoring because in debug mode'
      return

    @reportProblem "window.onerror:" + text, ->
      reportingError = false
    , ->
      reportingError = false

  # Don't overload the user with errors
  debouncedHandleOnError = _.debounce(handleOnError, 5000, true)

  window.onerror = (message, file, line, column, errorObj) ->
    if reportingError
      # Get text of message
      text = "window.onerror: #{message} at #{file}:#{line}:#{column}"

      # Add stack
      if errorObj?
        text = text + "\n" + errorObj.stack

      console.error "Ignoring error: #{text}"
      return

    debouncedHandleOnError(message, file, line, column, errorObj)

  @restore = ->
    window.onerror = oldWindowOnError
  return

ProblemReporter.register = (url, version, getLogin) ->
  ProblemReporter.instances = {}  unless ProblemReporter.instances

  return ProblemReporter.instances[url] if ProblemReporter.instances[url]

  ProblemReporter.instances[url] = new ProblemReporter(url, version, getLogin)

  return ProblemReporter.instances[url] 

module.exports = ProblemReporter  