functions = require('firebase-functions')
reddit = require('redwrap')
admin = require('firebase-admin')
async = require 'async'
admin.initializeApp functions.config().firebase
cors = require('cors')(origin: true)


# // Create and Deploy Your First Cloud Functions
# // https://firebase.google.com/docs/functions/write-firebase-functions
#
exports.helloWorld2 = functions.https.onRequest (request, response) ->
  cors request, response, =>
    admin.database().ref("/users").set {}, (err) ->
      return response.send 'okzz'

exports.helloWorld = functions.https.onRequest (request, response) ->
  total = 0
  async.eachSeries [0..30], ((item, loop_done) ->
    admin.database().ref("config/before").once 'value', (snap) ->
      {count, before} = snap.val()
      reddit.list('new').count(count).limit(100).before before, (err, data, res) ->
        last_item = 0
        children = data?.data?.children or []
        total += children.length
        async.forEachOf children, ((obj, key, next) ->
          admin.database().ref("/users/#{obj.data.author}").push {
            utc: obj.data.created_utc
            link: obj.data.permalink
          }, next
        ), ->
          admin.database().ref("config/before").set {
            before: before or data.data.before
            count: children.length
          }, ->
            if not data.data.before or not children.length
              return response.send("processed: #{total}")
            loop_done()
  ), ->
    response.send("processed: #{total}")

