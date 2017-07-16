test   = require 'tape'
devicemqtt = require '../src/device-mqtt'

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
	client = null
	client = devicemqtt Object.assign({}, config, { clientId })
	return client

teardown = (client) ->
	client.destroy()


test 'client connection', (assert) ->
	client = setup 'client1'
	client.once 'connected', ->
		teardown client
		assert.pass 'client receives a `connected` event when connects to the broker'
		assert.end()

	client.connect()


test 'client sending a message)', (assert) ->
	client = setup 'client2'
	client.once 'connected', ->

		assert.throws (() ->
			client.send action: '', payload: 'payload', dest: 'dest'),
			'No action provided!',
			'the function should throw an error if no action value is provided'

		assert.throws (() ->
			client.send payload: 'payload', dest: 'dest'),
			'No action provided!',
			'the function should throw an error if no action field is provided'

		assert.throws (() ->
			client.send action: 'action', payload: 'payload', dest: ''),
			'No action provided!',
			'the function should throw an error if no action field is provided'

		assert.throws (() ->
			client.send action: 'action', payload: 'payload'),
			'No action provided!',
			'the function should throw an error if no action field is provided'

		assert.doesNotThrow (() ->
			client.send action: 'action', payload: 'payload', dest: 'dest'),
			'the function should not throw an error'

		teardown client
		assert.end()

	client.connect()
