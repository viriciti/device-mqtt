EventEmitter = require 'events'
mqtt         = require 'mqtt'

MAIN_TOPIC = 'device-mqtt'
QOS        = 2


class Emitter extends EventEmitter

module.exports = ({ host, port, clientId }, mqttInstance) ->
	if !!mqttInstance
		throw new Error 'ClientId must be provided!' unless clientId

	_client = new Emitter
	_socket = new Emitter
	_mqtt = null

	connect = ->
		if mqttInstance
			_mqtt = mqttInstance
		else
			_mqtt = mqtt.connect "mqtt://#{host}:#{port}", { clientId, clean: false }

		_mqtt.on 'error', (error) ->
			_client.emit 'error', error

		_mqtt.on 'connect', (connack) ->
			###
				The connack.sessionPresent is set to `true` if
				the client has already a persistent session.
				If the session is there, there is no need to
				subscribe again to the topics.
			###
			if connack.sessionPresent
				_client.emit 'connected', _createSocket()
				return _startListeningToMessages()

			_subscribeFirstTime (error) ->
				_client.emit 'error', error if error
				_client.emit 'connected', _createSocket()

		_mqtt.on 'reconnecting', ->
			_client.emit 'reconnecting'

		_mqtt.once 'close', ->
			_client.emit 'disconnected'


	destroy = (cb) ->
		_mqtt.end cb




	_subscribeFirstTime = (cb) ->
		_startListeningToMessages()
		_mqtt.subscribe(
			"#{MAIN_TOPIC}/#{clientId}/+",
			{ qos: QOS },
			(error, granted) ->
				if error
					errorMsg = "Error subscribing to actions topic. Reason: #{error.message}"
					return cb new Error errorMsg
				cb()
		)

	_startListeningToMessages = ->
		_mqtt.on 'message', (topic, message) ->
			_socket.emit 'message', topic, message


	_createSocket = ->
		api_commands = require './api_commands'
		{ send } = api_commands
			mqttInstance: _mqtt
			socket: _socket
			socketId: clientId

		api_crud = require './api_crud'
		{ createCollection } = api_crud
			mqttInstance: _mqtt
			socket: _socket
			socketId: clientId

		_socket.send = send
		_socket.createCollection = createCollection
		_socket




	_createClient = ->
		_client.connect = connect
		_client.destroy = destroy
		_client

	return _createClient()
