func get_ipc():
	match OS.get_name():
		"Windows":
			return WindowsIPC.new()
		_:
			print("Tried to get an IPC for an unsupported platform: ", OS.get_name())
			return null

class IPC:
	extends Node

	const IPC_VERSION = 1
	const OP_HANDSHAKE = 0
	const OP_FRAME = 1
	const OP_CLOSE = 2
	const OP_PING = 3
	const OP_PONG = 4

	var connected = false
	var recv_thread = Thread.new()
	var recv_mutex = Mutex.new()
	var client_id = null
	var last_error = null

	signal connected
	signal disconnected
	signal handshake(config, user)
	signal error
	signal message(op, data)

	func ipc_connect():
		var err = _connect()
		if err == OK:
			handshake()
			recv_thread.start(self, "_recv_thread")
			connected = true
			emit_signal("connected")

	func handshake():
		var response = send_recv({
			'v': 1,
			'client_id': client_id,
			'nonce': null
		}, OP_HANDSHAKE, false)
		if response['op'] == OP_FRAME and response['data']['cmd'] == 'DISPATCH' and response['data']['evt'] == 'READY':
			# successful handshake
			emit_signal("handshake", response['data']['data']['config'], response['data']['data']['user'])
		else:
			if response['op'] == OP_CLOSE:
                close()
			_error(response['data'])
			
	func _error(err):
		last_error = err
		push_error(err)

	func close():
		connected = false
		emit_signal("disconnected")

	func send_recv(data, op = OP_FRAME, generate_nonce = true):
		var sent_payload = send(data, op, generate_nonce)
		var nonce = sent_payload.get('nonce')
		var reply = null
		while true:
			# TODO timeout
			reply = recv()
			if reply['data'].get('nonce') == nonce:
				return reply
			else:
				print("received unexpected reply; ", reply)
		return

	func send(data, op = OP_FRAME, generate_nonce = true):
		# Auto-generate nonce based on data + random generated numbers
		if !data.has("nonce") && generate_nonce:
			data["nonce"] = str(data.hash() + (randi() % 100))
		var payload = _encode(op, data)
		_write(payload)
		return data

	func recv():
		var header = _recv_header()
		var payload = _recv_exactly(header["length"])
		payload = payload.get_string_from_utf8()
		var data = JSON.parse(payload).result
		print("recieved data ", data)
		emit_signal("message", header["op"], data)
		return {
			"op": header["op"],
			"data": data
		}

	func _recv_thread():
		while true:
			recv_mutex.lock()
			recv()
			recv_mutex.unlock()

	func _recv_header():
		var header = _recv_exactly(8)
		var op = _ri32le(header, 0)
		var packet_len = _ri32le(header, 4)
		return {
			"op": op,
			"length": packet_len
		}

	func _recv_exactly(size):
		var buf = PoolByteArray()
		var size_remaining = size
		while size_remaining:
			var chunk = _recv(size_remaining)
			if chunk != null:
				buf.append_array(chunk)
				size_remaining -= len(chunk)
		return buf

	func _encode(op, data):
		data = JSON.print(data)
		var length = len(data)
		var packet = PoolByteArray()
		packet = _wi32le(packet, op, 0)
		packet = _wi32le(packet, length, 4)
		packet = _buffer_write(packet, data, 8, length)
		return packet

	func _wi32le(buffer, value, offset):
		value = +value
		offset = offset >> 0
		if value < 256:
			buffer.insert(offset, value)
		else:
			buffer.insert(offset, value % 256)
		buffer.insert(offset + 1, value >> 8)
		buffer.insert(offset + 2, value >> 16)
		buffer.insert(offset + 3, value >> 24)
		return buffer

	func _ri32le(buffer, offset = 0):
		var result = 0
		for power in range(4):
			result += buffer[offset + power] * pow(256, power);
		return result

	func _buffer_write(buffer : PoolByteArray, string, offset, length):
		for i in range(length):
			#if typeof(buffer[offset+i]) != TYPE_INT:
			#	push_error("OUT_OF_BOUNDS")
			buffer.insert(offset+i, string[i].to_ascii()[0])
		return buffer

	func _connect():
		pass

	func _write(data):
		pass

	func _recv(size):
		pass

	func _close():
		pass

class WindowsIPC:
	extends IPC
	
	const PIPE_PATTERN = "\\\\?\\pipe\\discord-ipc-{}"
	var pipe : File = null
	
	func _connect():
		for i in range(10):
			pipe = File.new()
			var path = PIPE_PATTERN.replace("{}", str(i))
			print("attempting to open ", path)
			var err = pipe.open(path, File.READ_WRITE)
			if err != OK:
				pipe.close()
				pipe = null
				print("failed to connect to pipe ", i, ": ", err)
			else:
				# This is the only good way for Discord to sense Godot
				pipe.get_len()
				print("opened ", path)
				break
		if pipe:
			return OK
		else:
			return ERR_CANT_OPEN
	
	func _write(data):
		pipe.store_buffer(data)
		# This is the only good way for Discord to sense Godot
		pipe.get_len()
	
	func _recv(size):
		return pipe.get_buffer(size)
	
	func _close():
		pipe.close()
		pipe = null