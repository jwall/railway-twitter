oauth = require("oauth")
sys = require("util")
_twitterConsumerKey = undefined
_twitterConsumerSecret = undefined
_host = undefined
_apiHost = "http://twitter.com"
_apiSecureHost = "https://twitter.com"
_callbackPath = "/twitter_callback"
TWITTER_CONNECT_EVENT = "twitterConnect"

exports.init = initTwitterConnect = ->
  console.log "Initializing twitter connect..."
  try
    settings = require("#{app.root}/config/environment").TwitterAPI
  catch e
    console.log "Could not init Twitter Auth extension, env-specific settings not found in config/environment"
    console.log "Error:", e.message
  initApp settings if settings

consumer = ->
  new oauth.OAuth(_apiHost + "/oauth/request_token", _apiSecureHost + "/oauth/access_token", _twitterConsumerKey, _twitterConsumerSecret, "1.0A", _host + _callbackPath, "HMAC-SHA1")

initApp = (settings) ->
  _twitterConsumerKey = settings.key
  _twitterConsumerSecret = settings.secret
  _host = settings.url
  app.get settings.connectPath or "/twitter_connect", (req, res) ->
    gotToken = (error, oauthToken, oauthTokenSecret, results) ->
      if error
        redirectBack req, res,
          error: "Error getting OAuth request token : " + sys.inspect(error)
      else
        req.session.twitter =
          oauthRequestToken: oauthToken
          oauthRequestTokenSecret: oauthTokenSecret

        res.redirect _apiSecureHost + "/oauth/authorize?oauth_token=" + oauthToken
    console.log req.headers
    req.session.beforeTwitterAuth = req.headers.referer
    delete req.session.twitter

    consumer().getOAuthRequestToken gotToken

  _callbackPath = callbackPath  if settings.callbackPath
  app.get settings.callbackPath or "/twitter_callback", (req, res) ->
    twitterCallback = (error, oauthAccessToken, oauthAccessTokenSecret, results) ->
      gotData = (error, data, response) ->
        if error
          redirectBack req, res,
            error: "Error getting twitter screen name : " + sys.inspect(error)

          console.log "gotData:", error
        else
          data = JSON.parse(data)  if typeof data is "string"
          req.session.twitter = data
          req.session.twitter.oauthAccessToken = oauthAccessToken
          req.session.twitter.oauthAccessTokenSecret = oauthAccessTokenSecret
          app.emit TWITTER_CONNECT_EVENT, req.session.twitter, req, res
          if settings.autoRedirect
            console.log "autoredirect"
            redirectBack req, res
      if error
        res.send "Error getting OAuth access token : " + sys.inspect(error), 500
        return
      consumer().get _apiHost + "/account/verify_credentials.json", oauthAccessToken, oauthAccessTokenSecret, gotData
    consumer().getOAuthAccessToken req.session.twitter.oauthRequestToken, req.session.twitter.oauthRequestTokenSecret, req.query.oauth_verifier, twitterCallback
redirectBack = (req, res, flash) ->
  location = req.session and req.session.beforeTwitterAuth or "/"
  delete req.session.beforeTwitterAuth

  if flash
    if flash.error
      req.flash "error", flash.error
    else req.flash "info", flash.info  if flash.info
  res.redirect location
