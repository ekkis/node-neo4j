$ = require 'underscore'
http = require 'http'

class @Error extends Error

    constructor: (@message='Unknown error', @neo4j={}) ->
        @name = 'neo4j.' + @constructor.name
        Error.captureStackTrace @, @constructor

    #
    # Accepts the given HTTP client response, and if it represents an error,
    # creates and returns the appropriate Error instance from it.
    # If the response doesn't represent an error, returns null.
    #
    @_fromResponse: (resp) ->
        {body, headers, statusCode} = resp

        return null if statusCode < 400

        # TODO: Do some status codes (or perhaps inner `exception` names)
        # signify Transient errors rather than Database ones?
        ErrorType = if statusCode >= 500 then 'Database' else 'Client'
        ErrorClass = exports["#{ErrorType}Error"]

        message = "[#{statusCode}] "
        logBody = statusCode >= 500     # TODO: Config to always log body?

        if body?.exception
            message += "[#{body.exception}] #{body.message or '(no message)'}"
        else
            statusText = http.STATUS_CODES[statusCode]  # E.g. "Not Found"
            reqText = "#{resp.req.method} #{resp.req.path}"
            message += "#{statusText} response for #{reqText}"
            logBody = true  # always log body if non-error returned

        if logBody and body?
            message += ": #{JSON.stringify body, null, 4}"

        new ErrorClass message, body

    #
    # Accepts the given error object from a transactional Cypher response, and
    # creates and returns the appropriate Error instance for it.
    #
    @_fromTransaction: (obj) ->
        # http://neo4j.com/docs/stable/rest-api-transactional.html#rest-api-handling-errors
        # http://neo4j.com/docs/stable/status-codes.html
        {code, message} = obj
        [neo, classification, category, title] = code.split '.'

        ErrorClass = exports[classification]    # e.g. DatabaseError
        message = "[#{category}.#{title}] #{message or '(no message)'}"

        # TODO: Some errors (always DatabaseErrors?) can also apparently have a
        # `stack` property with the Java stack trace. Should we include it in
        # our own message/stack, in the DatabaseError case at least?
        # (This'd be analagous to including the body for 5xx responses above.)

        new ErrorClass message, obj

    # TODO: Helper to rethrow native/inner errors? Not sure if we need one.

class @ClientError extends @Error

class @DatabaseError extends @Error

class @TransientError extends @Error