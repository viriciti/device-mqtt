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

	createCollection = (collectionName, localState, collectionObjCb) ->
		singleObjCollTopic = "#{socketId}/#{COLLECTIONS_TOPIC}/#{collectionName}"
		collectionObjCb(_createCollectionObject singleObjCollTopic, localState)




	_createCollectionObject = (singleObjCollTopic, localState) ->
		collectionObj = {}

		# Create methods for collectionObj
		# ADD
		collectionObj.add = ({ key, value }, done) ->
			if localState[key]
				return done new Error "Key `#{key}` already existent!"

			localState[key] = value
			value = JSON.stringify value if (_isJson value) || (Array.isArray value)

			_updateCollectionObject singleObjCollTopic, localState, ->
				_mqtt.pub "#{singleObjCollTopic}/#{key}",
				value,
				{ qos: QOS, retain: true },
				(error) ->
					return done error if error
					done()

		# REMOVE
		collectionObj.remove = (key, done) ->
			if !localState[key]
				return done new Error "Cannot remove key `#{key}`: not existent!"

			delete localState[key]

			_updateCollectionObject singleObjCollTopic, localState, ->
				_mqtt.pub "#{singleObjCollTopic}/#{key}",
				null,
				{ qos: QOS, retain: true },
				(error) ->
					return done error if error
					done()

		# UPDATE
		collectionObj.update = ({ key, value }, done) ->
			if !localState[key]
				return done new Error "Cannot update key `#{key}`: not existent!"

			localState[key] = value
			value = JSON.stringify value if (_isJson value) || (Array.isArray value)

			_updateCollectionObject singleObjCollTopic, localState, ->
				_mqtt.pub "#{singleObjCollTopic}/#{key}",
				value,
				{ qos: QOS, retain: true },
				(error) ->
					return done 'error', error if error
					done()


		# GET
		collectionObj.get = (key) ->
			return null if not localState[key]
			return JSON.parse localState[key] if isJson localState[key]
			return localState[key]

		# GET ALL
		collectionObj.getAll = ->
			return localState

		return collectionObj




	_isJson = (object) ->
		return isJson object, [passObjects=true]


	_updateCollectionObject = (singleObjCollTopic, localState, cb) ->
		_mqtt.pub singleObjCollTopic,
			JSON.stringify(localState),
			{ qos: QOS, retain: true },
			(error) ->
				return done error if error
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
