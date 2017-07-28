test   = require 'tape'
devicemqtt = require '../src/index'

# config =
# 	host: 'toke-mosquitto'
# 	port: 1883

config =
	host: 'localhost'
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
	client = devicemqtt(Object.assign {}, config, { clientId })
	return client

teardown = (client) ->
	client.destroy()




test 'client sending a message', (assert) ->
	client = setup 'client_send'
	client.once 'connected', (socket) ->

		assert.comment "Test: no action value is provided."
		assert.throws (() ->
			socket.send action: '', payload: 'payload', dest: 'dest'),
				'the function should throw an error if no action value is provided.'

		assert.comment "Test: no action field is provided."
		assert.throws (() ->
			socket.send payload: 'payload', dest: 'dest'),
				'the function should throw an error if no action field is provided.'

		assert.comment "Test: no dest value is provided."
		assert.throws (() ->
			socket.send action: 'action', payload: 'payload', dest: ''),
				'the function should throw an error if no dest field is provided.'

		assert.comment "Test: no dest field is provided."
		assert.throws (() ->
			socket.send action: 'action', payload: 'payload'),
				'the function should throw an error if no dest field is provided.'

		assert.comment "Test: action is not a string"
		assert.throws(() ->
			socket.send { action: ['muahah'], payload: 'payload', dest: 'dest' },
				'the function should throw an error if action is not a string'
		)

		assert.comment "Test: dest is not a string"
		assert.throws(() ->
			socket.send { action: 'action', payload: 'payload', dest: ['muahah'] },
				'the function should throw an error if dest is not a string'
		)

		assert.comment "Test: all fields and values are provided."
		assert.doesNotThrow (() ->
			socket.send { action: 'action', payload: 'payload', dest: 'dest' }
			, ->
					return
			, ->
					teardown client
					assert.end()
			),
			'the function should not throw an error.'

	client.connect()
