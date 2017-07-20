EventEmitter = require 'events'
randomstring = require 'randomstring'
isJson       = require 'is-json'

QOS = 2
COLLECTIONS_TOPIC = 'collections'
COLLECTION_POSITION = 2


class Emitter extends EventEmitter

module.exports = ({ mqttInstance, socket, socketId }) ->
	throw new Error 'No mqtt connection provided!' unless mqttInstance
	throw new Error 'ClientId must be provided!' unless socketId
	DB_REGEX = new RegExp "^#{socketId}\/collections\/(.)+$"

	_mqtt = mqttInstance
	_socket = socket

	createCollection = (collectionName, localState, collectionObjCb, cb) ->
		singleObjCollTopic = "#{socketId}/#{COLLECTIONS_TOPIC}/#{collectionName}"
		singleItemsCollTopic = "#{socketId}/#{COLLECTIONS_TOPIC}/#{collectionName}/+"

		collectionTopics = [
			singleObjCollTopic
			singleItemsCollTopic
		]

		if localState?
			return _mqtt.subscribe collectionTopics, { qos: QOS }, (error) ->
				return _socket.emit 'error', error if error
				cb? 'OK'
				collectionObjCb(_createCollectionObject singleObjCollTopic, localState)

		collectionObjCb(_createCollectionObject singleObjCollTopic, localState)




	_createCollectionObject = (singleObjCollTopic, localState) ->
		collectionObj = {}

		# Create methods for collectionObj
		# ADD
		collectionObj.add = ({ key, value }, done) ->
			if localState[key]
				return _socket.emit 'error',
					new Error "Key `#{key}` already existent!"

			localState[key] = value
			value = JSON.stringify value if _isJson value

			_updateCollectionObject singleObjCollTopic, localState, ->
				_mqtt.publish "#{singleObjCollTopic}/#{key}",
				value,
				{ qos: QOS, retain: true },
				(error) ->
					return _socket.emit 'error', error if error
					done 'OK'

		# REMOVE
		collectionObj.remove = (key, done) ->
			if !localState[key]
				return _socket.emit 'error',
					new Error "Cannot remove key `#{key}`: not existent!"

			delete localState[key]

			_updateCollectionObject singleObjCollTopic, localState, ->
				_mqtt.publish "#{singleObjCollTopic}/#{key}",
				null,
				{ qos: QOS, retain: true },
				(error) ->
					return _socket.emit 'error', error if error
					done 'OK'

		# UPDATE
		collectionObj.update = ({ key, value }, done) ->
			if !localState[key]
				return _socket.emit 'error',
					new Error "Cannot update key `#{key}`: not existent!"

			localState[key] = value
			value = JSON.stringify value if _isJson value

			_updateCollectionObject singleObjCollTopic, localState, ->
				_mqtt.publish "#{singleObjCollTopic}/#{key}",
				value,
				{ qos: QOS, retain: true },
				(error) ->
					return _socket.emit 'error', error if error
					done 'OK'


		# GET
		collectionObj.get = (key) ->
			return null if not localState[key]
			return JSON.parse localState[key] if isJson localState[key]
			return localState[key]

		return collectionObj

	_isJson = (object) ->
		return isJson object, [passObjects=true]


	_updateCollectionObject = (singleObjCollTopic, localState, cb) ->
		_mqtt.publish singleObjCollTopic,
			JSON.stringify(localState),
			{ qos: QOS, retain: true },
			(error) ->
				return _socket.emit 'error', error if error
				cb()


	handleMessage = (topic, message) ->
		singleItemCollTopicRegex = new RegExp "^#{socketId}\/collections\/(.)+\/(.)+$"
		collectionName = _extractCollectionName topic

		if singleItemCollTopicRegex.test topic
			message = JSON.parse message if isJson message
			_socket.emit "collection:#{collectionName}", message
		else
			message = JSON.parse message
			_socket.emit 'collection', collectionName, message


	_extractCollectionName = (topic) ->
		(topic.split '/')[COLLECTION_POSITION]

	return {
		createCollection
		handleMessage
		dbRegex: DB_REGEX
	}
