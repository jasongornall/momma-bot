functions = require('firebase-functions')
reddit = require('redwrap')
admin = require('firebase-admin')
async = require 'async'
auth = require 'basic-auth'
admin.initializeApp functions.config().firebase
cors = require('cors')(origin: true)


# // Create and Deploy Your First Cloud Functions
# // https://firebase.google.com/docs/functions/write-firebase-functions
#
exports.helloWorld2 = functions.https.onRequest (request, response) ->
  cors request, response, =>
    admin.database().ref("/users").set {}, (err) ->
      return response.send 'okzz'

exports.newPosts = functions.https.onRequest (request, response) ->
  credentials = auth request
  if credentials?.name isnt functions.config().auth.name or credentials?.pass isnt functions.config().auth.pass
    return response.send('hack attempt')


  config = null
  current = Date.now()
  async.whilst ( ->
    Date.now() - current <= 1000 * 60
  ), ((loop_done) ->
    admin.database().ref("config").once 'value', (snap) ->
      config = snap.val()
      last = config.last
      reddit.list('new').limit 100, (err, data, res) ->

        last_item = 0
        children = data?.data?.children or []
        new_children = []
        for item in children
          if item.data.name is last
            break
          else
            new_children.push item

        if not new_children.length
          return setTimeout loop_done, 1000 * 3

        if err
          console.log(err)
          return response.send("processed early error")

        async.forEachOf new_children, ((obj, key, next) ->
          admin.database().ref("/users/#{obj.data.author}/#{obj.data.name}").set {
            utc: obj.data.created_utc
            link: obj.data.permalink
            title: obj.data.title
          }, next
        ), ->
          last = new_children[0]
          admin.database().ref("config/last").set last.data.name, ->
            setTimeout loop_done, 1000 * 3
  ), ->
    admin.database().ref("/users").once 'value', (doc) ->
      users = snap.val()
      async.forEachOf snap.val(), (user_data, user_key, callback) ->
        start_of_day = new Date()
        start_of_day = start_of_day.setHours(0,0,0)

        end_of_day = new Date()
        end_of_day = end_of_day.setHours(23,59,59)

        spam_keys = []
        purge_keys = []
        for key, value of user_data
          current_post = value.unix * 1000
          if current_post > start_of_day and current_post < end_of_day
            spam_count++
            spam_keys.push "/users/#{user_key}/#{key}"
          else if current_post < start_of_day
            purge_keys.push "/users/#{user_key}/#{key}"

        ((next)->
          if spam_keys?.length >= 4

            # do reddit post
            purge_keys = purge_keys.concat spam_keys
          else
            next()
        ) (_) ->
          async.each purge_keys, ((key, next) ->
            admin.database().ref(key).remove next
          ), ->
            return response.send('ok')






