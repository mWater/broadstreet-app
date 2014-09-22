# Miscellaneous testable utilities called by pages

login = require '../login'
context = require '../context'

exports.login = (username, password, ctx, success, error) ->
  console.log "Logging in as: #{username}"

  url = ctx.apiUrl + 'clients'
  req = $.ajax(url, {
    data : JSON.stringify({
      username: username
      password: password
      version: @version
      domain: "Broadstreet Ebola"
    }),
    contentType : 'application/json',
    type : 'POST'})

  req.done (data, textStatus, jqXHR) =>
    response = JSON.parse(jqXHR.responseText)

    # Login 
    login.setLogin(response)

    # Update context, first stopping old one
    ctx.stop()
    context.createLoginContext response, (newctx) =>
      _.extend ctx, newctx

      # Update groups
      ctx.db.groups.find({ members: login.user }, { fields: { groupname: 1 }, mode: "remote" }).fetch (groupDocs) ->
        ctx.login.groups = _.pluck(groupDocs, "groupname")
        success()
      , ctx.error

  req.fail (jqXHR, textStatus, errorThrown) =>
    console.error "Login failure: #{jqXHR.responseText} (#{jqXHR.status})"
    if jqXHR.status < 500 and jqXHR.status >= 400 and jqXHR.status != 404 # 404 means no connection sometimes
      alert(JSON.parse(jqXHR.responseText).error)
    else
      alert(T("Unable to login. Please check that you are connected to Internet"))
    error()

  