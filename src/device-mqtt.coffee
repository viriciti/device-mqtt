mqtt         = require 'mqtt'
EventEmitter = require 'events'
randomstring = require 'randomstring'

QOS               = 2
MAIN_TOPIC        = 'device-mqtt'
RESPONSE_SUBTOPIC = 'response'
ACTIONID_POSITION = 2
RESPONSE_POSITION = 3

class Emitter extends EventEmitter

module.exports = ({ host, port, clientId }) ->
	_client = new Emitter
	_mqtt   = null
	_prevMessage = null
	_actionListeners = {}

	connect = ->
		_mqtt = mqtt.connect "mqtt://#{host}:#{port}", { clientId, clean: false }

		_mqtt.once 'connect', ->
			_client.emit 'connected'

		_mqtt.on 'error', (error) ->
			console.log error.message


	listenToActionsAndResults = ->
		_startListening()


	send = (message, cb) ->
		{ action, dest, payload } = message
		throw new Error 'No action provided!' if !action
		throw new Error 'No dest provided!' if !dest

		actionMessage = JSON.stringify { action, payload, origin: clientId }

		actionId = randomstring.generate()
		topic    = _generatePubTopic actionId, message.dest

		console.log clientId
		console.log topic
		console.log actionMessage

		_mqtt.publish topic, actionMessage, { qos: QOS }, (error) ->
			return cb? error if error

			topic = _generateResponseTopic actionId, clientId
			_mqtt.subscribe topic, qos: QOS

			responseListener = new Emitter
			_actionListeners[actionId] = responseListener
			cb? null, 'OK', responseListener


	destroy = (cb) ->
		_mqtt.removeListener 'message', _messageHandler
		_mqtt.end cb




	_generatePubTopic = (actionId, dest) ->
		"#{MAIN_TOPIC}/#{dest}/#{actionId}"


	_startListening = ->
		_mqtt.on 'message', _messageHandler
		_mqtt.subscribe "#{MAIN_TOPIC}/#{clientId}/+", qos: QOS


	_messageHandler = (topic, message) ->
		if (topic.toString().split '/')[RESPONSE_POSITION]
			return _handleIncomingResults topic, message

		_handleIncomingActions topic, message


	_handleIncomingActions = (topic, message) ->
		{ action, payload, origin } = JSON.parse message.toString()
		actionId = _extractActionId topic

		_client.emit "#{action}", payload, _generateReplyObject origin, actionId


	_handleIncomingResults = (topic, message) ->
		{ statusCode, data } = JSON.parse message.toString()
		actionId = _extractActionId topic

		_actionListeners[actionId].emit 'result', { statusCode, data }

		_mqtt.unsubscribe topic, ->
			delete _actionListeners.actionId


	_extractActionId = (topic) ->
		topic = topic.toString()
		actionId = (topic.split '/')[ACTIONID_POSITION]
		return actionId


	_generateReplyObject = (origin, actionId) ->
		reply = {}
		reply.send = ({ type, data }, cb) ->
			responseMessage = _generateResponse { type, data }
			_mqtt.publish(
				_generateResponseTopic(actionId, origin),
				responseMessage,
				qos: QOS,
				(error) ->
					return cb? error if error
					cb? null, 'OK'
			)

		return reply


	_generateResponseTopic = (actionId, origin) ->
		"#{MAIN_TOPIC}/#{origin}/#{actionId}/#{RESPONSE_SUBTOPIC}"


	_generateResponse = ({ type, data }) ->
		throw new Error 'No data provided!' if !data
		responseType = (data) -> {
			success: JSON.stringify { statusCode: 'OK', data }
			failure: JSON.stringify { statusCode: 'ERROR', data }
		}

		responseType(data)[type]


	_createClient = ->
		_client.connect = connect
		_client.destroy = destroy
		_client.send = send
		_client.listenToActionsAndResults = listenToActionsAndResults
		return _client

	return _createClient()
