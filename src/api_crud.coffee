EventEmitter = require 'events'
randomstring = require 'randomstring'

QOS               = 2
MAIN_TOPIC        = 'device-mqtt'
RESPONSE_SUBTOPIC = 'response'
ACTIONID_POSITION = 2
RESPONSE_POSITION = 3

class Emitter extends EventEmitter

module.exports = ({ mqttInstance, socket, socketId }) ->
	throw new Error 'No mqtt connection provided!' unless mqttInstance
	throw new Error 'ClientId must be provided!' unless socketId

	_mqtt = mqttInstance
	_socket = socket

	createCollection = (collectionName, cb) ->
		collectionTopics = [
			"#{socketId}/#{collectionName}/+"
			"#{socketId}/#{collectionName}"
		]

		_mqtt.subscribe collectionTopics, (error) ->
			_socket.emit 'error', error if error
			cb? 'OK'


	# _socket.on 'message', _messageHandler
	return { createCollection }
