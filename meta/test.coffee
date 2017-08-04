devicemqtt = require '../src/index'

config =
	host: 'localhost'
	port: 1883
	clientId: 'test'

d = devicemqtt config

d.on 'connected', (socket) ->
	console.log 'connected'

	socket.on 'test', console.log

	socket.customSubscribe topic: 'test', (error, granted) ->
		console.log 'sent!'

d.connect()
