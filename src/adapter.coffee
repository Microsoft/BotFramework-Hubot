#
# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license.
#
# Microsoft Bot Framework: http://botframework.com
#
# Bot Builder SDK Github:
# https://github.com/Microsoft/BotBuilder
#

Util = require 'util'
Timers = require 'timers'

BotBuilder = require 'botbuilder'
{ Robot, Adapter, TextMessage, User } = require 'hubot'
Middleware = require './adapter-middleware'
MicrosoftTeamsMiddleware = require './msteams-middleware'

LogPrefix = "hubot-botframework-adapter:"

class BotFrameworkAdapter extends Adapter
    constructor: (robot) ->
        super robot
        @appId = process.env.BOTBUILDER_APP_ID
        @appPassword = process.env.BOTBUILDER_APP_PASSWORD
        @endpoint = process.env.BOTBUILDER_ENDPOINT || "/api/messages"
        @defaultRoom = process.env.BOTBUILDER_ROOM_WEBHOOK || ""
        robot.logger.info "#{LogPrefix} Adapter loaded. Using appId #{@appId}"

        @connector  = new BotBuilder.ChatConnector {
            appId: @appId
            appPassword: @appPassword
        }

        @connector.onEvent (events, cb) => @onBotEvents events, cb

    using: (name) ->
        MiddlewareClass = Middleware.middlewareFor(name)
        new MiddlewareClass(@robot)

    onBotEvents: (activities, cb) ->
        @robot.logger.info "#{LogPrefix} onBotEvents"
        activities = [activities] unless Array.isArray activities
        @handleActivity activity for activity in activities

    handleActivity: (activity) ->
        @robot.logger.info "#{LogPrefix} Handling activity Channel: #{activity.source}; type: #{activity.type}"
        event = @using(activity.source).toReceivable(activity)
        if event?
            @robot.receive event

    send: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} send"
        if context.room? and -1 isnt context.room.indexOf "http"
            @messageRoom context, messages...
            return
        @reply context, messages...

        #for msg in messages
        #    payload = @using(context).toSendable(context, msg)
        #    if !Array.isArray(payload)
        #        payload = [payload]
        #    @connector.send payload, (err, _) ->
        #        if err
        #            throw err

    reply: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} reply"
        console.log context
        for msg in messages
            activity = context.user.activity
            payload = @using(activity.source).toSendable(context, msg)
            if !Array.isArray(payload)
                payload = [payload]
            @connector.send payload, (err, _) ->
                if err
                    throw err

    messageRoom: (context, messages...) ->
        @robot.logger.info "#{LogPrefix} messageRoom"
        for msg in messages
            data = JSON.stringify({
                text: msg
            })
            console.log context
            if context.room? or @defaultRoom
                @robot.http(context.room ||= @defaultRoom)
                    .header('Content-Type', 'application/json')
                    .post(data) (err, res, body) =>
                        if err
                            @robot.logger.error err
                            @robot.logger.info body

    run: ->
        @robot.router.post @endpoint, @connector.listen()
        @robot.logger.info "#{LogPrefix} Adapter running."
        Timers.setTimeout (=> @emit "connected"), 1000

module.exports = {
    Middleware,
    MicrosoftTeamsMiddleware
}

module.exports.use = (robot) ->
    new BotFrameworkAdapter robot
