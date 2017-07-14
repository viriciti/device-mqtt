test   = require 'tape'
devicemqtt = require '../src/index'

config =
	host: 'toke-mosquitto'
	port: 1883

# config =
# 	host: 'localhost'
# 	port: 7654

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




test 'constructor', (assert) ->
	assert.comment 'Test: no clientId value passed to the constructor'
	assert.throws (() ->
		client = devicemqtt Object.assign({}, config, { clientId: '' }),
			'the constructor should throw an error if no clientId field is provided.'
	)

	assert.comment 'Test: no clientId field passed to the constructor'
	assert.throws (() ->
		client = devicemqtt Object.assign({}, config, { notTheClientId: '' }),
			'the constructor should throw an error if no clientId value is provided.'
	)

	assert.comment 'Test: clientId passed to the constructor'
	assert.doesNotThrow (() ->
		client = devicemqtt Object.assign({}, config, { clientId: 'client' }),
			'the constructor should not throw an error.'
	)

	assert.end()


test 'client connection', (assert) ->
	client = setup 'client1'
	client.once 'connected', (socket) ->
		teardown client
		assert.pass 'client receives a `connected` event when connects to the broker'
		assert.end()

	client.connect()


test 'client disconnection', (assert) ->
	client = setup 'client2'

	client.once 'disconnected', ->
		assert.pass 'client receives a `disconnected` event when disconnects from the broker'
		assert.end()

	client.once 'connected', ->
		teardown client

	client.connect()