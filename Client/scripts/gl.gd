extends Node2D
@onready var peer = null
@onready var serverIP = ""
@onready var serverPort = 31400
@onready var connected = false
@onready var surrogate = null
@onready var failed = 0


func _ready() -> void:
	pass


func rpc_connections(sur):
	surrogate = sur
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_disconnected_from_server)
	join_server()

func _connected_to_server() -> void:
	gl.connected = true
	dialog(surrogate, "Connected to Server")
	failed = 0

func _disconnected_from_server() -> void:
	gl.connected = false
	get_tree().quit()

func _connection_failed():
	gl.connected = false
	if failed == 0:
		dialog(surrogate, "Connection Failed")
	elif failed == 10:
		dialog(surrogate, "Make sure that the server is set up properly and reconnect Later.")
	print('failed')
	failed += 1

func join_server() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(serverIP, serverPort)
	multiplayer.multiplayer_peer = peer

func goToBoard(node: Node):
	node.get_node('Body').queue_free()
	node.get_node('Board').process_mode = Node.PROCESS_MODE_ALWAYS

func popSprite(n: Node2D, v: Vector2, st, nm, sc=Vector2(4, 4)):
	if n.has_node(nm):
		n.get_node(nm).free()
	var s = Sprite2D.new()
	s.texture = load(st)
	s.name = nm
	s.position = v
	s.scale = sc
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.add_child(s)
	n.move_child(s, -1)
	return s

func popArrow(n: Node2D, nn: String, v: Vector2, v2: Vector2):
	if n.has_node(nn):
		n.get_node(nn).free()
	var s = NinePatchRect.new()
	s.texture = load('res://assets/arrow.png')
	s.name = nn
	s.position = v - Vector2(8, 8)
	s.patch_margin_left = 7
	s.patch_margin_top = 2
	s.patch_margin_right = 7
	s.patch_margin_bottom = 2
	s.scale = Vector2(4, 4)
	s.size = Vector2(16, 16)
	s.pivot_offset = Vector2(8, 8)
	var x_size = abs(v2 - v)
	x_size = sqrt(x_size.x ** 2 + x_size.y ** 2) / 4 + 8
	s.size.x = x_size
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.add_child(s)
	n.move_child(s, -1)
	return s

func sound(n: AudioStreamPlayer, p):
	n.set_stream(load(p))
	n.play()

func dialog(n, t):
	if not is_instance_valid(n):
		return
	for child in n.get_children():
		if is_instance_valid(child):
			if child is AcceptDialog or child is ConfirmationDialog:
				child.free()
	var text = AcceptDialog.new()
	text.dialog_text = t
	text.visible = true
	n.add_child(text)
	text.popup_centered()
	return text

func confirm(n, t):
	for child in n.get_children():
		if is_instance_valid(child):
			if child is AcceptDialog or child is ConfirmationDialog:
				child.free()
	var text = ConfirmationDialog.new()
	text.dialog_text = t
	text.visible = true
	n.add_child(text)
	text.popup_centered()
	return text
