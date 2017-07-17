# (require 'leaked-handles').set {
# 	fullStack: true
# 	timeout: 30000
# 	debugSockets: true
# }

# After running the first test, restart the broker before testing again

test       = require 'tape'
devicemqtt = require '../src/index'
{ fork }   = require "child_process"

# Only for pipeline tests
# config =
# 	host: 'toke-mosquitto'
# 	port: 1883

# Only for development
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

setup = (clientId) ->
	client = null
	client = devicemqtt Object.assign({}, config, { clientId })
	return client

forkClient = (clientId) ->
	client = fork "./meta/client.coffee"
	client.send Object.assign({}, config, { clientId })
	return client

teardownForkedClient = (client) ->
	client.kill 'SIGKILL'

teardown = (client, cb) ->
	client.destroy cb




test 'client sends an action and receives a response', (assert) ->
	# Test data
	expectedResponse = { statusCode: 'OK', data: 'somedata' }
	actionToSend =
		action: 'theaction'
		payload: 'payload'
		dest: 'receiver1'

	# Setting up clients
	sender = setup 'sender1'
	receiver = forkClient 'receiver1'

	# Start test
	###
		message is used first to check that the the receiver is connected,
		only after it happens, the sender can connect. In this it is
		possible to simulate an interaction between a device (receiver)
		and server (sender).
		The second message should contain the payload that the receiver
		received and the ack of the response it sent back.
	###
	receiver.on 'message', (message) ->
		if message is 'connected'
			sender.connect()
		else
			{ receivedPayload, ack } = message
			assert.equal receivedPayload, actionToSend.payload,
				"The payload should be equal to the sent payload: `#{actionToSend.payload}`"
			assert.equal ack, 'OK',
				'If the receiver published a response correctly, the ack should be `OK`'

	sender.once 'connected', (socket) ->
		socket.send(
			actionToSend
		, (response) ->
				assert.deepEqual response, expectedResponse,
					"The response should be equal to #{JSON.stringify expectedResponse}"
				teardownForkedClient receiver
				teardown sender
				assert.end()
		, (error, ack) ->
				assert.equal ack, 'OK',
					'If the sender published an action correctly, the ack should be `OK`'
		)


test 'client sends an action, but the receiver goes offline and then up again', (assert) ->
	# Test data
	expectedResponse = { statusCode: 'OK', data: 'somedata' }
	actionToSend =
		action: 'theaction'
		payload: 'payload'
		dest: 'receiver2'

	# Setting up clients
	sender = setup 'sender2'
	receiver = forkClient 'receiver2'

	# Start test
	###
		message is used first to check that the the receiver is connected,
		only after it happens, the sender can connect. In this it is
		possible to simulate an interaction between a device (receiver)
		and server (sender).
		The second message should contain the payload that the receiver
		received and the ack of the response it sent back.
	###
	receiver.on 'message', (message) ->
		if message is 'connected'
			sender.connect()
			assert.comment "Putting receiver2 down..."
			teardownForkedClient receiver

			# Recreate the receiver after some time
			timeout = 5000
			assert.comment "Restarting receiver2 in #{timeout / 1000} s"
			setTimeout ->
				receiver = forkClient 'receiver2'
			, timeout
		else
			{ receivedPayload, ack } = message
			assert.equal receivedPayload, actionToSend.payload,
				"The payload should be equal to the sent payload: #{actionToSend.payload}"
			assert.equal ack, 'OK',
				'If the receiver published a response correctly, the ack should be OK'

	sender.on 'connected', (socket) ->
		socket.send(
			actionToSend
		, (response) ->
				assert.deepEqual response, expectedResponse,
					"The response should be equal to #{JSON.stringify expectedResponse}"
				teardownForkedClient receiver
				teardown sender
				assert.end()
		, (error, ack) ->
				assert.equal ack, 'OK',
					'If the sender published an action correctly, the ack should be `OK`'
		)


test 'the sender send an action and it goes offline', (assert) ->
	# Test data
	expectedResponse = { action: 'theaction', statusCode: 'OK', data: 'somedata' }
	actionToSend =
		action: 'theaction'
		payload: 'payload'
		dest: 'receiver3'

	# Setting up clients
	sender = setup 'sender3'
	receiver = forkClient 'receiver3'

	# Start test
	###
		message is used first to check that the the receiver is connected,
		only after it happens, the sender can connect. In this it is
		possible to simulate an interaction between a device (receiver)
		and server (sender).
		The second message should contain the payload that the receiver
		received and the ack of the response it sent back.
	###
	receiver.on 'message', (message) ->
		if message is 'connected'
			sender.connect()
		else
			{ receivedPayload, ack } = message
			assert.equal receivedPayload, actionToSend.payload,
				"The payload should be equal to the sent payload: #{actionToSend.payload}"
			assert.equal ack, 'OK',
				'If the receiver published a response correctly, the ack should be OK'

	sender.once 'connected', (socket) ->
		socket.send(
			actionToSend
		, (response) ->
				return
		, (error, ack) ->
				assert.equal ack, 'OK',
					'If the sender published an action correctly, the ack should be `OK`'

				assert.comment "Tearing down sender3..."
				teardown sender, ->
					# Recreate the sender after some time
					timeout = 5000
					assert.comment "Restarting sender3 in #{timeout / 1000} s"
					setTimeout ->
						sender = setup 'sender3'
						sender.once 'connected', (socket) ->
							socket.on 'response', (response) ->
								assert.deepEqual response, expectedResponse,
									"The response should be equal to #{JSON.stringify expectedResponse}"
								teardownForkedClient receiver
								teardown sender
								assert.end()

						sender.connect()
					, timeout
		)
