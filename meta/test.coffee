devicemqtt = require '../src/index'

config =
	host: 'localhost'
	port: 1883
	clientId: 'test'

d = devicemqtt config

d.on 'reconnecting', ->
	console.log 'reconnecting'

d.on 'connected', (socket) ->
	console.log 'connected'
	_handler = (test) ->
		console.log test

	socket.on 'test', _handler
	console.log socket.listeners 'test'

	socket.on 'disconnected', ->
			socket.removeListener 'test', _handler

	socket.customSubscribe topic: 'test', (error, granted) ->
		console.log 'subscribed!'

d.connect()
