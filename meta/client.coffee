process.title = 'testclient'

devicemqtt = require '../src/index'

process.on 'message', (config) ->
	client = devicemqtt config

	client.once 'connected', (socket) ->
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
