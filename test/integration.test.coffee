# (require 'leaked-handles').set {
# 	fullStack: true
# 	timeout: 30000
# 	debugSockets: true
# }

test       = require 'tape'
devicemqtt = require '../src/device-mqtt'

config =
	host: 'localhost'
	port: 7654
	clientId: 'integrationTest'

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

teardown = (client, cb) ->
	client.destroy cb


test 'client send a message when the broker is reacheable', (assert) ->
	expected = 'OK'

	client = setup 'sender1'
	client.once 'connected', ->
		client.send({
			action: 'action'
			payload: 'payload'
			dest: 'dest'
		},(error, ack, listener) ->
				assert.equal ack, expected, 'The acknowledgement message should be OK.'
				teardown client, ->
					assert.end()
	)

	client.connect()



test 'client sends an action to another client', (assert) ->
	expectedPayload = 'payload'
	client1 = setup 'sender2'
	client2 = setup 'receiver2'

	client2.once 'connected', ->
		client2.listenToActionsAndResults()
		client2.on 'theaction', (payload) ->
			assert.equal payload, expectedPayload,
				'The client received the correct payload'
			teardown client2, ->
				teardown client1, ->
					assert.end()

	client1.once 'connected', ->
		client1.send action: 'theaction', payload: 'payload', dest: 'receiver2'

	client1.connect()
	client2.connect()



test 'client receives an action and sends a response', (assert) ->
	client1 = setup 'sender3'
	client2 = setup 'receiver3'

	client2.once 'connected', ->
		client2.on 'theaction', (payload, reply) ->
			assert.ok typeof reply.send is 'function'

			reply.send { type: 'success', data: 'somedata' }, (error, ack) ->
				assert.equal ack, 'OK'
				teardown client2
				assert.end()

		client2.listenToActionsAndResults()

	client1.once 'connected', ->
		client1.send action: 'theaction', payload: 'payload', dest: 'receiver3'
		teardown client1

	client1.connect()
	client2.connect()



test 'client sends an action and receives a response', (assert) ->
	expectedResponse = { statusCode: 'OK', data: 'somedata' }

	client1 = setup 'sender4'
	client2 = setup 'receiver4'

	client2.once 'connected', ->
		client2.on 'theaction', (payload, reply) ->
			reply.send { type: 'success', data: 'somedata' }

		client2.listenToActionsAndResults()

	client1.once 'connected', ->
		client1.send({
				action: 'theaction'
				payload: 'payload'
				dest: 'receiver4'
			}
		, (error, ack, listener) ->
				listener.once 'result', (response) ->
					assert.deepEqual response, expectedResponse,
						"The response should be equal to #{JSON.stringify expectedResponse}"
					teardown client2, ->
						teardown client1, ->
							assert.end()

				client1.listenToActionsAndResults()
		)

	client1.connect()
	client2.connect()



test 'client sends an action, but the receiver is offline', (assert) ->
	expectedResponse = { statusCode: 'OK', data: 'somedata' }

	client1 = setup 'sender5'
	client2 = setup 'receiver5'
	receiverTimeout = null
	senderTimeout = null

	client2.once 'connected', ->
		client2.listenToActionsAndResults()
		assert.comment 'The receiver will go down and then up again in 2 seconds...'

		receiverTimeout = setTimeout ->
			teardown client2
			client2 = setup 'receiver5'
			client2.once 'connected', ->
				client2.on 'theaction', (payload, reply) ->
					reply.send { type: 'success', data: 'somedata' }

				client2.listenToActionsAndResults()
			client2.connect()
		, 2000

	client2.connect()

	assert.comment 'The sender will send in 6 seconds...'
	senderTimeout = setTimeout ->

		client1.once 'connected', ->
			client1.send({
					action: 'theaction'
					payload: 'payload'
					dest: 'receiver5'
				},

				(error, ack, listener) ->
					listener.on 'result', (response) ->
						assert.deepEqual response, expectedResponse,
							"The response should be equal to #{JSON.stringify expectedResponse}"
						teardown client2, ->
							teardown client1, ->
								clearTimeout receiverTimeout
								clearTimeout senderTimeout
								assert.end()

					client1.listenToActionsAndResults()
			)

		client1.connect()
	, 6000
