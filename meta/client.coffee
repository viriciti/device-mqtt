process.title = 'testclient'

devicemqtt = require '../src/index'
mqtt = require 'mqtt'

process.on 'message', (config) ->
	client = devicemqtt config

	client.once 'connected', (socket) ->
		process.once 'message', (message) ->
			if message is 'storeAction'
				m = mqtt.connect 'mqtt://localhost:7654', { clientId: 'client_sending_retain_msgs2' }
				m.on 'connect', ->
					m.publish(
						'client_api_db_emit_retained/collections/testcollection',
						(JSON.stringify { test: 'test' }),
						{ retain: true, qos: 2 }
					)

		console.log "Forked client: #{config.clientId} connected!"
		process.send 'connected'

		socket.on 'action:theaction', (payload, reply) ->
			reply.send { type: 'success', data: 'somedata' }, (error, ack) ->
				process.send { receivedPayload: payload, ack: ack }

		socket.on 'action:theaction2', (payload, reply) ->
			reply.send { type: 'error', data: 'somedata' }, (error, ack) ->
				process.send { receivedPayload: payload, ack: ack }

		socket.on 'action:longtimeout', (payload, reply) ->
			setTimeout ->
				reply.send { type: 'error', data: 'somedata' }, (error, ack) ->
					process.send { receivedPayload: payload, ack: ack }
			, 5000

	client.connect()
