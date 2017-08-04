test       = require 'tape'
devicemqtt = require '../src/index'
{ fork }   = require "child_process"

# config =
# 	host: 'toke-mosquitto'
# 	port: 1883

config =
	host: 'toke-mosquitto'
	port: 1883

### Testing template

test 'What component aspect are you testing?', (assert) ->
	actual = 'What is the actual output?'
	expected = 'What is the expected output?'

	assert.equal actual, expected, 'What should the feature do?'

	assert.end()

###############################################################

setup = (clientId)->
	client = devicemqtt(Object.assign {}, config, { clientId })
	return client

teardown = (client) ->
	client.destroy()

forkClient = (clientId) ->
	client = fork "./meta/client.coffee"
	client.send Object.assign({}, config, { clientId })
	return client

teardownForkedClient = (client) ->
	client.kill 'SIGKILL'




test 'The client creates a new global collection', (assert) ->
	client = setup 'client_create'
	testobject = {}

	client.once 'connected', (socket) ->
		socket.createGlobalCollection(
			'testglobalcollection'
		, testobject
		,
			(collection) ->
				assert.ok typeof collection is 'object',
					'should return an object'
				assert.ok collection.add,
					'the object should have a add property'
				assert.ok collection.remove,
					'the object should have a remove property'
				assert.ok collection.update,
					'the object should have a update property'
				assert.ok collection.get,
					'the object should have a get property'

				teardown client
				assert.end()
		)

	client.connect()


test 'Global collection: The client saves items, delete one and updates the other', (assert) ->

	client = setup 'client_api_db_global'
	testobject = {}
	testObjectAfterAdd =
		key: 'value'
		key1: justAnObject: 'value1'
		key2: 'value2'
	testObjectAfterRemove = key: 'value', key2: 'value2'
	testObjectAfterUpdate = key: 'updatedvalue', key2: 'value2'

	client.once 'connected', (socket) ->
		socket.createGlobalCollection(
			'testglobalcollection'
		,	testobject
		,
			(collection) ->
				assert.comment 'Adding two items...'
				collection.add { key: 'key', value: 'value' }, (error) ->

					collection.add { key: 'key1', value: { justAnObject: 'value1' } }, (error) ->
						collection.add { key: 'key2', value: 'value2' }, (error) ->
							assert.deepEqual testObjectAfterAdd, testobject,
								'the local state should have the added items'

							collection.remove 'key1', (error) ->
								assert.deepEqual testObjectAfterRemove, testobject,
									'the local state should not have the removed item'

								collection.update { key: 'key', value: 'updatedvalue' }, (error) ->
									assert.deepEqual testObjectAfterUpdate, testobject,
										'the local state should have an updated item'

									teardown client
									assert.end()
		)

	client.connect()


test 'Global collection: The client removes an item', (assert) ->
	client = setup 'client_api_db_global_remove'
	testobject = {}

	client.once 'connected', (socket) ->
		socket.createGlobalCollection(
			'testglobalcollection'
		,	testobject
		,
			(collection) ->
				collection.remove 'key1', (error) ->
					assert.equal error.message, 'Cannot remove key `key1`: not existent!',
						'should emit an error the key does not exist'
					teardown client
					assert.end()
		)

	client.connect()


test 'Global collection: The client updates an item', (assert) ->
	client = setup 'client_api_db_global_update'
	testobject = {}

	client.once 'connected', (socket) ->
		socket.createGlobalCollection(
			'testglobalcollection'
		,	testobject
		,
			(collection) ->
				collection.update { key: 'key1', value: 'updatedvalue' }, (error) ->
					assert.equal error.message, 'Cannot update key `key1`: not existent!',
						'should emit an error the key does not exist'

					teardown client
					assert.end()
		)

	client.connect()


test 'Global collection: The client saves an item & gets it from the local state', (assert) ->
	client = setup 'client_api_db_global_get'
	testobject = {}
	testObjectAfterAdd = { key: 'value' }

	client.once 'connected', (socket) ->
		socket.once 'global:collection:testglobalcollection', (collection) ->
			testobject = collection

		socket.createGlobalCollection(
			'testglobalcollection'
		,	testobject
		,
			(collection) ->
				assert.comment 'Adding one item...'
				collection.add { key: 'key', value: 'value' }, (error) ->
					assert.equal 'value', collection.get 'key'
					teardown client
					assert.end()
		)

	client.connect()


test 'Global collection: get all item of the collection with getAll()', (assert) ->
	client = setup 'client_api_db_global_get_all'
	testobject = {}
	testObjectAfterAdd = { key: 'value', key1: [ 'value1' ] }

	client.once 'connected', (socket) ->
		socket.createGlobalCollection(
			'testglobalcollection'
		,	testobject
		,
			(collection) ->
				assert.comment 'Adding two items...'
				collection.add { key: 'key', value: 'value' }, (error) ->
					collection.add { key: 'key1', value: [ 'value1' ] }, (error) ->
						assert.deepEqual testObjectAfterAdd, collection.getAll()
						teardown client
						assert.end()
	)

	client.connect()


test 'Global collection: Retrieve single item of a collection', (assert) ->
	client = setup 'client_api_db_global_retrieve_item'
	collectionName = 'testglobalcollection'
	testobject = {}
	receivedCollection = 'value'

	client.once 'connected', (socket) ->
		socket.createGlobalCollection(
			collectionName
		,	testobject
		,
			(collection) ->
				assert.comment 'Adding one item...'
				collection.add { key: 'key', value: 'value' }, (error) ->
					teardown client

					client = setup 'client_api_db_global_retrieve_item'
					client.once 'connected', (socket) ->
						console.log 'connected'
						socket.on "global:collection:#{collectionName}", (collection) ->
							assert.equal receivedCollection, collection
							teardown client
							assert.end()

					assert.comment 'Reconnecting in 5 seconds... \n\n'
					setTimeout ->
						client.connect()
					, 5000
		)

	client.connect()

test 'Global collection: Retrieve full collection object', (assert) ->
	client = setup 'client_api_db_global_retrieve_object'
	collectionName = 'testglobalcollection'
	testobject = {}
	receivedCollection = { key: 'value', key1: { test: 'test' } }

	client.once 'connected', (socket) ->
		socket.createGlobalCollection(
			collectionName
		,	testobject
		,
			(collection) ->
				assert.comment 'Adding one item...'
				collection.add { key: 'key', value: 'value' }, (error) ->
					collection.add { key: 'key1', value: { test: 'test' } }, (error) ->
						teardown client

						client = setup 'client_api_db_global_retrieve_object'
						client.once 'connected', (socket) ->
							console.log 'connected'
							socket.on "global:collection", (collName, collection) ->
								assert.equal collName, collectionName
								assert.deepEqual receivedCollection, collection
								teardown client
								assert.end()

						assert.comment 'Reconnecting in 5 seconds... \n\n'
						setTimeout ->
							client.connect()
						, 5000
		)

	client.connect()


test 'Global collection: The client saves items, delete one and updates the other from a global collection', (assert) ->
	client = setup 'client_api_db_global_global_collection'
	testobject = {}
	testObjectAfterAdd =
		key: 'value'
		key1: justAnObject: 'value1'
		key2: 'value2'
	testObjectAfterRemove = key: 'value', key2: 'value2'
	testObjectAfterUpdate = key: 'updatedvalue', key2: 'value2'

	client.once 'connected', (socket) ->
		socket.createGlobalCollection(
			'testglobalcollection'
		,	testobject
		,
			(collection) ->
				assert.comment 'Adding two items...'
				collection.add { key: 'key', value: 'value' }, (error) ->

					collection.add { key: 'key1', value: { justAnObject: 'value1' } }, (error) ->
						collection.add { key: 'key2', value: 'value2' }, (error) ->
							assert.deepEqual testObjectAfterAdd, testobject,
								'the local state should have the added items'

							collection.remove 'key1', (error) ->
								assert.deepEqual testObjectAfterRemove, testobject,
									'the local state should not have the removed item'

								collection.update { key: 'key', value: 'updatedvalue' }, (error) ->
									assert.deepEqual testObjectAfterUpdate, testobject,
										'the local state should have an updated item'

									teardown client
									assert.end()
		)

	client.connect()

test 'REMINDER!!!!!!', (assert) ->
	assert.comment 'RUN THE NEXT TESTS ONE BY ONE, RESTARTING THE BROKER EACH TIME'
	assert.end()

# For this test the broker needs to be restarted.
test.skip 'Global collection: The client saves an item and receives the new config object', (assert) ->
	client = setup 'client_api_db_global_event1'
	testobject = {}
	testObjectAfterAdd = { config: 'config' }

	client.once 'connected', (socket) ->
		socket.on 'global:collection:testglobalcollection', (collection) ->
			assert.deepEqual collection, testObjectAfterAdd,
				'the collection should have the added item'

			teardown client
			assert.end()

		socket.createGlobalCollection(
			'testglobalcollection'
		,	testobject
		,
			(collection) ->
				assert.comment 'Adding one item...'
				collection.add { key: 'key', value: config: 'config' }, (error) ->
					return
		)

	client.connect()
