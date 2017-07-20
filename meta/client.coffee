process.title = 'testclient'

devicemqtt = require '../src/device-mqtt'

process.on 'message', (config) ->
	client = devicemqtt config

	client.once 'connected', ->
		console.log "Forked client: #{config.clientId} connected!"
		process.send 'connected'

		client.on 'theaction', (payload, reply) ->
			reply.send { type: 'success', data: 'somedata' }, (error, ack) ->
				process.send { receivedPayload: payload, ack: ack }

	client.connect()
