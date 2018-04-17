_ = require "underscore"

devicemqtt = require '../src/index'

socket  = null
counter = 0

config =
	host: 'localhost'
	port: 1883
	clientId: 'test'+ _.random 100000, 1000000
	extraOpts: resubscribe: true

d = devicemqtt config

d.on 'reconnecting', ->
	console.log 'reconnecting'


setHandlersOnec = _.once (socket) ->
	socket.on 'disconnected', ->
		console.log "socket disconnected!"

d.on 'connected', (s) ->
	socket = s
	console.log 'connected! socket:', socket.id, _.object (_.keys socket._events), _.map (_.values socket._events), (v) -> v.length or 1
	console.log 'connected! client:', d.id, _.object (_.keys d._events), _.map (_.values d._events), (v) -> v.length or 1
	console.log socket.listeners 'test'

	socket.customSubscribe { topic: 'test' }, (error, granted) ->
		console.log 'subscribed!'

	setHandlersOnec socket

	_handler = (message) ->
		console.log "test message:", message

	socket.on 'test', _handler

d.connect
	topic: "naaah"
	payload: "yolo"

interval = setInterval =>
	console.log "try sending"
	if socket
		console.log "socket is there"
		socket?.customPublish
			topic: "test"
			message: "ke#{++counter}"
	else
		console.log "not there yet"
, 1000

setTimeout =>
	clearInterval interval
	console.log "DESTROY!!"
	d.destroy()
, 20000
