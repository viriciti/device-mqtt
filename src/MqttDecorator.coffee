{ extend } = require 'underscore'

module.exports = (mqtt) ->
	sub = (topic, opts, cb) ->
		mqtt.subscribe topic, opts, cb

	pub = (topic, message, opts, cb) ->
		mqtt.publish topic, message, opts, cb

	return extend mqtt, { sub, pub }
