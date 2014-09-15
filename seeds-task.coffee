fs = require 'fs'
JsonClient = require('request-json').JsonClient

module.exports = ->
  done = @async()

  # Query database for rows
  seeds = {}

  jsonClient = new JsonClient "http://api.mwater.co/v3/"

  # Only get tests
  jsonClient.get 'forms?selector={"_id": { "$in" : ["dd909cb39f544ff7b5cdce6951b6a63f", "f4b712bf0643456cb8dcd7b96c7dfd3c", "ef7cbe23b8f04c66ae64a307f126e641"] }}', (err, res, body) ->
    if res.statusCode != 200
      throw new Error("Server error")

    seeds.forms = body
    
    fs.writeFileSync('dist/js/seeds.js', 'seeds=' + JSON.stringify(seeds) + ';')
    done()


