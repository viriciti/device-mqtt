test   = require 'tape'
devicemqtt = require '../src/index'

# config =
# 	host: 'toke-mosquitto'
# 	port: 1883
# 	clientId: 'integrationTest'
config =
	host: 'localhost'
	port: 7654

### Testing template

test 'What component aspect are you testing?', (assert) ->
	actual = 'What is the actual output?'
	expected = 'What is the expected output?'

	assert.equal actual, expected, 'What should the feature do?'

	assert.end()

###############################################################

setup = (clientId)->
	client = null
	client = devicemqtt Object.assign({}, config, { clientId })
	return client

teardown = (client) ->
	client.destroy()




test.only 'The client creates a new collection', (assert) ->
	client = setup 'client_create'
	client.once 'connected', (socket) ->
		socket.createCollection 'testcollection', (ack) ->
			assert.equal ack, 'OK',
				'should return `OK` if the collection is created correctly'
			teardown client
			assert.end()

	client.connect()


test 'The client saves a new item in a collection', (assert) ->
	assert.end()
