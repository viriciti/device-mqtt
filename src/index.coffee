# (require 'leaked-handles').set {
# 	fullStack: true
# 	timeout: 30000
# 	debugSockets: true
# }

EventEmitter = require 'events'
mqtt         = require 'mqtt'

MAIN_TOPIC        = 'device-mqtt'
COLLECTIONS_TOPIC = 'collections'
QOS               = 2


class Emitter extends EventEmitter

module.exports = ({ host, port, clientId }) ->
	ACTIONS_TOPIC        = "#{MAIN_TOPIC}/#{clientId}/+"
	SINGLE_ITEM_DB_TOPIC = "#{clientId}/collections/+"
	OBJECT_DB_TOPIC      = "#{clientId}/collections/+/+"

	if !clientId
		throw new Error 'clientId must be provided'

	if (clientId.indexOf '/') >= 0
		throw new Error 'clientId must not include a `/`'

	api_commands = null
	api_db       = null
	_client      = new Emitter
	_socket      = new Emitter
	_mqtt        = null


	connect = (will) ->
		connectionOptions = {}

		if will
			will = Object.assign {}, will, { qos: 2, retain: true }
			connectionOptions = { clientId, clean: false, will }
		else
			connectionOptions = { clientId, clean: false }

		_mqttUrl = "mqtt://#{host}:#{port}"
		_mqtt = mqtt.connect _mqttUrl, connectionOptions
		_init _mqtt
		_initApis _mqtt


	destroy = (cb) ->
		_mqtt.end cb


	customPublish = ({ topic, message, opts }, cb) ->
		_mqtt.publish topic, message, opts, (error) ->
			return cb error if error
			cb()




	_initApis = (_mqtt) ->
		api_commands = (require './api_commands')(
			mqttInstance: _mqtt
			socket: _socket
			socketId: clientId
		)

		api_db = (require './api_db')(
			mqttInstance: _mqtt
			socket: _socket
			socketId: clientId
		)

	_subscribeFirstTime = (cb) ->
		_startListeningToMessages()
		_mqtt.subscribe(
			[ACTIONS_TOPIC, SINGLE_ITEM_DB_TOPIC, OBJECT_DB_TOPIC],
			{ qos: QOS },
			(error, granted) ->
				if error
					errorMsg = "Error subscribing to actions topic. Reason: #{error.message}"
					return cb new Error errorMsg
				cb()
		)

	_subscribeToDbTopics = (cb) ->
		_mqtt.subscribe(
			[SINGLE_ITEM_DB_TOPIC, OBJECT_DB_TOPIC],
			{ qos: QOS },
			(error, granted) ->
				if error
					errorMsg = "Error subscribing to actions topic. Reason: #{error.message}"
					return cb new Error errorMsg
				cb()
		)

	_startListeningToMessages = ->
		_mqtt.on 'message', _messageHandler

	_messageHandler = (topic, message) ->
		{ responseRegex, actionRegex } = api_commands
		{ dbRegex } = api_db

		topic = topic.toString()
		message = message.toString()

		if responseRegex.test topic
			api_commands.handleMessage topic, message, 'result'
		else if actionRegex.test topic
			api_commands.handleMessage topic, message, 'action'
		else if dbRegex.test topic
			api_db.handleMessage topic, message



	_createSocket = ->
		{ send } = api_commands
		{ createCollection } = api_db

		_socket.send = send
		_socket.createCollection = createCollection
		_socket.customPublish = customPublish
		_socket


	_init = (mqttInstance) ->
		_onConnection = (connack) ->
			###
				The connack.sessionPresent is set to `true` if
				the client has already a persistent session.
				If the session is there, there is no need to
				subscribe again to the topics.
			###
			if connack.sessionPresent
				###
					Subscribing to the db topics is needed because
					even if there is a persistent session, the
					retained messages are not received.
				###
				return _subscribeToDbTopics (error) ->
					return _client.emit 'error', error if error
					_client.emit 'connected', _createSocket()
					_startListeningToMessages()

			_subscribeFirstTime (error) ->
				_client.emit 'error', error if error
				_client.emit 'connected', _createSocket()

		_onReconnect = ->
			_client.emit 'reconnecting'

		_onClose = ->
			_client.emit 'disconnected'

		_onError = (error) ->
			_client.emit 'error', error

		mqttInstance.on 'error', _onError
		mqttInstance.on 'connect', _onConnection
		mqttInstance.on 'reconnect', _onReconnect
		mqttInstance.on 'close', _onClose




	_createClient = ->
		_client.connect = connect
		_client.destroy = destroy
		_client

	return _createClient()
