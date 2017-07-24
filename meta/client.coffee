process.title = 'testclient'

devicemqtt = require '../src/index'

process.on 'message', (config) ->
	client = devicemqtt config

	client.once 'connected', (socket) ->
		console.log "Forked client: #{config.clientId} connected!"
		process.send 'connected'

		socket.on 'theaction', (payload, reply) ->
			reply.send { type: 'success', data: 'somedata' }, (error, ack) ->
				process.send { receivedPayload: payload, ack: ack }

	client.connect()
