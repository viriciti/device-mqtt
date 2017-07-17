EventEmitter = require 'events'
randomstring = require 'randomstring'

QOS               = 2
MAIN_TOPIC        = 'device-mqtt'
RESPONSE_SUBTOPIC = 'response'
ACTIONID_POSITION = 2
RESPONSE_REGEXP   = new RegExp "^#{MAIN_TOPIC}\/(.)+\/([a-zA-Z0-9])+\/#{RESPONSE_SUBTOPIC}"
ACTION_REGEXP     = new RegExp "^#{MAIN_TOPIC}\/(.)+\/([a-zA-Z0-9])+"

class Emitter extends EventEmitter

module.exports = ({ mqttInstance, socket, socketId }) ->
	throw new Error 'No mqtt connection provided!' unless mqttInstance
	throw new Error 'ClientId must be provided!' unless socketId

	_socket = socket
	_mqtt   = mqttInstance
	_actionResultCallbacks = {}

	send = (message, resultCb, mqttCb) ->
		{ action, dest, payload } = message
		throw new Error 'No action provided!' if !action
		throw new Error 'No dest provided!' if !dest
		throw new Error 'Action must be a string' if typeof message.action isnt 'string'
		throw new Error 'Dest must be a string' if typeof message.dest isnt 'string'

		actionMessage = JSON.stringify { action, payload, origin: socketId }

		actionId = randomstring.generate()
		topic    = _generatePubTopic actionId, message.dest

		_mqtt.publish topic, actionMessage, { qos: QOS }, (error) ->
			return mqttCb error if error

			topic = _generateResponseTopic actionId, socketId
			_mqtt.subscribe topic, qos: QOS, (error, granted) ->
				return _socket.emit 'error', error if error

				_actionResultCallbacks[actionId] = resultCb
				mqttCb null, 'OK'




	_messageHandler = (topic, message) ->
		topic = topic.toString()

		if RESPONSE_REGEXP.test topic
			return _handleIncomingResults topic, message

		if ACTION_REGEXP.test topic
			return _handleIncomingActions topic, message


	_handleIncomingActions = (topic, message) ->
		{ action, payload, origin } = JSON.parse message.toString()
		actionId = _extractActionId topic

		reply = _generateReplyObject origin, actionId, action

		_socket.emit "action", action, payload, reply
		_socket.emit "action:#{action}", payload, reply


	_handleIncomingResults = (topic, message) ->
		{ action, statusCode, data } = JSON.parse message.toString()
		actionId = _extractActionId topic

		_mqtt.unsubscribe topic, (error) ->
			return _socket.emit 'error', error if error

			if _actionResultCallbacks[actionId]
				_actionResultCallbacks[actionId]({ statusCode, data })
				delete _actionResultCallbacks[actionId]
			else
				_socket.emit 'response', { action, statusCode, data }



	_extractActionId = (topic) ->
		topic = topic.toString()
		actionId = (topic.split '/')[ACTIONID_POSITION]
		return actionId

	_generateReplyObject = (origin, actionId, action) ->
		reply = {}
		reply.send = ({ type, data }, cb) ->
			responseMessage = _generateResponse { type, data, action }

			_mqtt.publish(
				_generateResponseTopic(actionId, origin),
				responseMessage,
				qos: QOS,
				(error) ->
					return cb? error if error
					_mqtt.unsubscribe _generatePubTopic(actionId, socketId), (error) ->
						return cb? error if error
						cb? null, 'OK'
			)

		return reply



	_generateResponseTopic = (actionId, origin) ->
		"#{MAIN_TOPIC}/#{origin}/#{actionId}/#{RESPONSE_SUBTOPIC}"

	_generatePubTopic = (actionId, dest) ->
		"#{MAIN_TOPIC}/#{dest}/#{actionId}"

	_generateResponse = ({ type, data, action }) ->
		throw new Error 'No data provided!' if !data
		responseType = (data) -> {
			success: JSON.stringify { statusCode: 'OK', data, action }
			failure: JSON.stringify { statusCode: 'ERROR', data, action }
		}

		responseType(data)[type]


	_socket.on 'message', _messageHandler
	return { send }
