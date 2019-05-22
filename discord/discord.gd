extends Node

var id : String
var ipc = null
var timeout = null
var discord_config = null
var user = null
var can_use = false

func _ready():
	ipc = preload("./ipc.gd").new().get_ipc()
	if ipc:
		can_use = true
		ipc.connect("message", self, "_ipc_message")
		ipc.connect("handshake", self, "_ipc_handshake")

func _request(command, args = null):
	var data = {
		'cmd': command
	}
	if args != null:
		data['args'] = args

	return ipc.send_recv(data)

func start():
	ipc.client_id = id
	ipc.ipc_connect()

func _ipc_message(op, data):
	pass

func _ipc_handshake(config, user):
	discord_config = config
	self.user = user
	pass

func get_guild(id):
	var args = {
		'channel_id': id
	}
	if timeout != null:
		args['timeout'] = timeout

	return _request("GET_GUILD", args)

func get_guilds():
	var args = null
	if timeout != null:
		args = { 'timeout': timeout }

	return _request("GET_GUILDS", args)

func get_channel(id):
	var args = {
		'channel_id': id
	}
	if timeout != null:
		args['timeout'] = timeout

	return _request("GET_CHANNEL", args)

func get_channels(id):
	var args = {
		'guild_id': id
	}
	if timeout != null:
		args['timeout'] = timeout

	return _request("GET_CHANNELS", args)

func set_certified_devices(devices):
	return _request("SET_CERTIFIED_DEVICES", { 'devices': devices })

func set_user_voice_settings(id, volume = null, pan = null, mute = null):
	var args = {
		'user_id': id,
	}
	if volume != null:
		args['volume'] = volume
	if pan != null:
		args['pan'] = pan
	if mute != null:
		args['mute'] = mute

	return _request("SET_USER_VOICE_SETTINGS", args)

func select_text_channel(id, force = false):
	var args = {
		'channel_id': id,
		'force': force
	}
	if timeout != null:
		args['timeout'] = timeout

	return _request("SELECT_TEXT_CHANNEL", args)

func get_voice_settings():
	return _request("GET_VOICE_SETTINGS")

func set_voice_settings(args):
	return _request("SET_VOICE_SETTINGS", args)

func set_activity(activity, pid = OS.get_process_id()):
	return _request("SET_ACTIVITY", {
		'pid': pid,
		'activity': activity
	})

func clear_activity(pid = OS.get_process_id()):
	return _request("SET_ACTIVITY", {
		'pid': pid
	})

func send_join_invite(id):
	return _request("SEND_ACTIVITY_JOIN_INVITE", {
		'user_id': id
	})

func send_join_request(id):
	return _request("SEND_ACTIVITY_JOIN_REQUEST", {
		'user_id': id
	})

func close_activity_join_request(id):
	return _request("CLOSE_ACTIVITY_JOIN_REQUEST", {
		'user_id': id
	})

func _tree_exiting():
	ipc.disconnect("message", self, "_ipc_message")
