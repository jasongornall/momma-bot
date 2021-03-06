functions = require('firebase-functions')
reddit = require('redwrap')
rawjs = require('raw.js')
reddit_rawjs = new rawjs('raw.js momma-bot v:1.0.0')
reddit_rawjs.setupOAuth2 functions.config().reddit.oauth_key, functions.config().reddit.oauth_password
admin = require('firebase-admin')
async = require 'async'
auth = require 'basic-auth'
_ = require 'underscore'
admin.initializeApp functions.config().firebase
cors = require('cors')(origin: true)


# // Create and Deploy Your First Cloud Functions
# // https://firebase.google.com/docs/functions/write-firebase-functions
#
# exports.helloWorld2 = functions.https.onRequest (request, response) ->
#   cors request, response, =>
#     admin.database().ref("/users").set {}, (err) ->
#       return response.send 'okzz'


# exports.helloWorld3 = functions.https.onRequest (request, response) ->
#   reddit_rawjs.auth {
#     'username': functions.config().reddit.username
#     'password': functions.config().reddit.password
#   }, (err, res) ->
#     response.send err or 'ok'

exports.newPosts = functions.https.onRequest (request, response) ->
  credentials = auth request
  if credentials?.name isnt functions.config().auth.name or credentials?.pass isnt functions.config().auth.pass
    console.log 'hack'
    return response.send('hack attempt')

  current = Date.now()
  reddit_rawjs.auth {
    'username': functions.config().reddit.username
    'password': functions.config().reddit.password
  }, (err, res) ->
    return response.send err if err
    async.whilst ( ->
      Date.now() - current <= 1000 * 50
    ), ((loop_done) ->
      admin.database().ref("config/last").once 'value', (snap) ->
        last = snap.val()
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
            if obj.data.author in [
              'AutoModerator'
              '-en-'
              'ImagesOfNetwork'
              'AutoNewspaperAdmin'
              'thefeedbot'
              'autotldr'
            ]
              return process.nextTick ->
                next()
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
      console.log 'processing finished'
      admin.database().ref("/users").once 'value', (snap) ->
        users = snap.val()

        console.log 'checking for spam'
        async.forEachOfSeries users, ((user_data, user_key, callback) ->
          start_of_day = new Date()
          start_of_day = start_of_day.setHours 0, 0, 0

          end_of_day = new Date()
          end_of_day = end_of_day.setHours 23, 59, 59

          spam_keys = []
          purge_keys = []
          for key, value of user_data
            current_post = parseInt(value.utc) * 1000
            if current_post >= start_of_day and current_post <= end_of_day
              spam_keys.push {
                path: "/users/#{user_key}/#{key}"
                user: key
                value: value
              }
            else if current_post < start_of_day
              purge_keys.push "/users/#{user_key}/#{key}"

          ((next)->
            if spam_keys?.length >= 4

              # do reddit post
              console.log 'forming template'
              template = """
                EXCUSE ME /u/ #{user_key} THAT'S ENOUGH INTERNET TODAY!

                I SEE YOU POSTING #{spam_keys.length} POSTS IN LESS THAN **FRIGGEN 24 HOURS**!!!!!\n\n
              """
              random_names = _.shuffle [
                'Another One!'
                'Really?'
                'You spent your time posting this?'
                'Shame!'
                'You Dishonor us!'
                'You call this productive?'
                'This is more important than your homework?'
                'Dissapointing'
                'What will your father think?'
                'No wonder your grades are awful!'
                'Terrible'
                'Your Generation is just awful'
                'Smoke Less pot please?'
                'You always were the under achiever'
                'You really embody the word failure'
                'This is how you repay my hard work!?'
                '20 pushups for this one'
                "Why can't you be normal?"
                'glued to the screen much?'
                'Go to your room!'
                'Wait till your father hears about this'
                'What did I do to deserve this?'
                'THIS is how you spend your time?'
                'Did you forget where the sun was?'
                'Are you just lonely or something?'
                'This is why you have no friends'
                'Pathetic'
                "I'm calling your father over this"
                'This was an hour you will never get back'
                '3 new gray hairs.. thanks'
              ]
              last_post = {
                utc: 0
              }
              spam_arr = []
              for spam_item, index in spam_keys
                comment = random_names[index] or ''
                template += "* [#{spam_item.value.title}](https://reddit.com/#{spam_item.value.link}) *#{comment}*\n\n"

                # get thread to comment on
                if spam_item.value.utc > last_post.utc
                  last_post = {
                    user: spam_item.user
                    utc: spam_item.value.utc
                  }
                spam_arr.push spam_item.path
              template += """
                \n\n
                ___
                **Go^Out^Side** **and** **Do^Anything^Else** **because** **Momma^Says^So**
              """
              reddit_rawjs.comment 't3_72aki6' or last_post.user, template, (e, data) ->

                finish = -> setTimeout next, 1000 * 3

                # try again if error
                if e

                  # special case for banned
                  if e.toString().indexOf('403') != -1
                    purge_keys = purge_keys.concat spam_arr

                  return finish()

                # kill the keys
                purge_keys = purge_keys.concat spam_arr
                return finish()
            else
              next()
          ) (_data) ->
            async.each purge_keys, ((key, next) ->
              admin.database().ref(key).remove next
            ), ->
              process.nextTick ->
                callback()
        ), ->
          console.log 'done'
          return response.send('ok')






