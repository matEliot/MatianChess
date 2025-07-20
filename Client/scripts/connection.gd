extends Node2D
@onready var VERSION = '1.4.1'
@onready var password = ""
@onready var surrogate = $Body

@onready var clock = $Board/Clock/Clock
@onready var clockAudio = $Board/Clock/Audio
@onready var holderVar = 0
@onready var holderVar2 = 0
@onready var holderVar3 = 0
@onready var holderVar4 = 0
@onready var holderVar5 = 0
@onready var sprite2d = null
@onready var holderBoolean = false
@onready var toPlay = true
@onready var activeGame = true
@onready var audio = $Audio
@onready var virgin = true
@onready var spectate = false
@onready var lowerThan15 = false
@onready var historyCooldown = 0
@onready var historyCooldownDuration = 0.3
@onready var groovy = false
@onready var groovyTween = null
@onready var currentBg = 0

@onready var positions = {
	'x': [$Board/Piece25.position.x, $Board/Piece20.position.x, $Board/Piece31.position.x, $Board/Piece30.position.x],
	'y': [$Board/Piece20.position.y, $Board/Piece10.position.y, $Board/Piece11.position.y,
	$Board/Piece11.position.y * 2 - $Board/Piece10.position.y,
	$Board/Piece25.position.y * 2 - $Board/Piece35.position.y,
	$Board/Piece25.position.y, $Board/Piece35.position.y, $Board/Piece33.position.y
	]
}
@onready var label = $Board/Eval
@onready var board = []
@onready var currentPiece = 0
@onready var currentPositionX = 8
@onready var currentPositionY = 8
@onready var movingPositionX = 8
@onready var movingPositionY = 8
@onready var currentSelectionX = 8
@onready var currentSelectionY = 8
@onready var gameOn = true
@onready var lastMove = []
@onready var captures = []
@onready var clockOn = false
@onready var clockCount = 7
@onready var strToScore = {'Q': 3, 'D': 2, 'P': 1}
@onready var holderColors = [Color(0.7, 0.3, 0.3), Color(0.7, 0.55, 0.3)]

@onready var systemId = OS.get_unique_id()
@onready var systemPassword = ''
@onready var playerId = -1
@onready var turn = 0
@onready var dragging = false
@onready var releaseCount = 0
@onready var moveHistory = []
@onready var captureHistory = []
@onready var clockHistory = []
@onready var timeHistory = []
@onready var history = []
@onready var timeline = 0
@onready var players = []
@onready var keepOnTop = ['serverPause', 'Selections']
@onready var clockJustStarted = false
@onready var rememberIncrement = 0
@onready var lastTyping = 0


func invertPositions():
	var newPositions = {"x": [], "y": []}
	for p in positions:
		for i in range(len(positions[p])):
			newPositions[p].append(positions[p][len(positions[p])-1-i])
	positions = newPositions

func ogSettings():
	for child in $Board.get_children():
		if 'Capture' in str(child.name):
			child.free()
	board = [[0, 0, 0, 0, 0, 2, 3, 3],
		[2, 1, 1, 0, 0, 1, 2, 3],
		[3, 2, 1, 0, 0, 1, 1, 2],
		[3, 3, 2, 0, 0, 0, 0, 0]]
	if playerId == 1 and virgin:
		invertPositions()
	currentPiece = 0
	clear_selection()
	currentPositionX = 8
	currentPositionY = 8
	movingPositionX = 8
	movingPositionY = 8
	currentSelectionX = 8
	currentSelectionY = 8
	gameOn = true
	lastMove = [0, 0, 0, 0]
	captures = ['', '']
	clockOn = false
	clockCount = 7
	turn = 0
	$Board/Eval.text = '[right]0[/right]'
	clock.region_rect.position.x = 0
	dragging = false
	releaseCount = 0
	history = []
	captureHistory = [['', '']]
	clockHistory = [7]
	moveHistory = []
	timeHistory = [[-1, -1]]
	lowerThan15 = false
	change_timeline(0, true)
	virgin = false

func _ready() -> void:
	$Body/ServerIP.grab_focus()
	load_inputs()
	$Board/ChatSp/Chat.meta_clicked.connect(_on_meta_clicked)

func _on_meta_clicked(meta):
	if meta == "newgameaccept":
		rpc('start_new_game', playerId, systemPassword, true)
	elif meta == "newgamedecline":
		rpc('start_new_game', playerId, systemPassword, false)
	elif meta == "acceptabandonvictory":
		rpc('claim_abandon_victory', playerId, systemPassword)
	elif meta == "takebackaccept":
		rpc('confirm_takeback', playerId, systemPassword, true)
	elif meta == "takebackdecline":
		rpc('confirm_takeback', playerId, systemPassword, false)

func getGroovy():
	groovy = not groovy
	updateTween()
	if not groovy:
		$Board/plainBG.modulate = Color(1, 1, 1)

func _process(_delta: float) -> void:
	for n in keepOnTop:
		if $Board.has_node(n):
			$Board.move_child($Board.get_node(n), -1)
	if currentPiece:
		if dragging:
			grabPiece(currentPositionX, currentPositionY).position = get_viewport().get_mouse_position()
		if Input.is_action_just_released("leftMouse"):
			snap()
			dragging = false
			releaseCount += 1
			clickReaction(true)
	if not $Board/ChatSp/Messagebox.has_focus() or not str($Board/ChatSp/Messagebox.text):
		if Time.get_unix_time_from_system() - historyCooldown >= historyCooldownDuration:
			if Input.is_action_pressed("ui_left"):
				if historyCooldown:
					historyCooldownDuration = 0.1
				historyCooldown = Time.get_unix_time_from_system()
				var sm = []
				if timeline-1 >= 0 and timeline-1 < len(moveHistory):
					sm = moveHistory[timeline-1]
					sm = [sm[2], sm[3], sm[0], sm[1]]
				change_timeline(-1, false, sm)
			if Input.is_action_pressed("ui_right"):
				if historyCooldown:
					historyCooldownDuration = 0.1
				historyCooldown = Time.get_unix_time_from_system()
				var slide_move = []
				if timeline >= 0 and timeline < len(moveHistory):
					slide_move = moveHistory[timeline]
				change_timeline(1, false, slide_move)
		if Input.is_action_just_released("ui_left") or Input.is_action_just_released("ui_right"):
			historyCooldown = 0
			historyCooldownDuration = 0.3
		if Input.is_action_just_pressed("ui_ctrl_left"):
			change_timeline(0, true)
		if Input.is_action_just_pressed("ui_ctrl_right"):
			change_timeline(len(history)-1, true)
		if Input.is_action_just_pressed("ui_ctrl_q"):
			_on_clock_input_event(0, 0, 0)
		if Input.is_action_just_pressed("ui_ctrl_c"):
			var rng = RandomNumberGenerator.new()
			var fromRange = range(5)
			fromRange.remove_at(currentBg)
			currentBg = fromRange[rng.randi_range(0, len(fromRange)-1)]
			$Board/plainBG.texture = load('res://assets/PlainBG%s.png' % [currentBg])
	if Input.is_action_just_pressed("ui_ctrl_t"):
		_on__input_event(0, 0, 0)
	if Input.is_action_just_pressed("ui_slash"):
		if not $Board/ChatSp/Messagebox.has_focus():
			$Board/ChatSp/Messagebox.grab_focus()
	if Input.is_action_just_pressed("ui_ctrl_n"):
		_on_new_game_input_event(0, 0, 0)
	if Input.is_action_just_pressed("ui_ctrl_f"):
		_on_flag_input_event(0, 0, 0)
	if Input.is_action_just_pressed("ui_ctrl_g"):
		getGroovy()
	if not str($Board/ChatSp/Messagebox.text):
		$Board/ChatSp/Limit.visible = false
	else:
		var currentMessageLength = len(str($Board/ChatSp/Messagebox.text))
		$Board/ChatSp/Limit.text = '[right]' + str(currentMessageLength) + '/300'
		if currentMessageLength >= 300:
			$Board/ChatSp/Limit.modulate = Color(0.7, 0.3, 0.3)
		else:
			$Board/ChatSp/Limit.modulate = Color(1, 1, 0.8)
		$Board/ChatSp/Limit.visible = true
	if playerId != -1:
		showTimes()

func updateTween():
	if groovyTween:
		groovyTween.kill()
	if not groovy:
		return
	groovyTween = create_tween()
	var rng = RandomNumberGenerator.new()
	var colorGoal = $Board/plainBG.modulate
	for i in range(3):
		var multiplier = {0: -1, 1: 1}[rng.randi_range(0, 1)]
		colorGoal[i] += rng.randf_range(0.3, 1) * multiplier
		colorGoal[i] = clamp(colorGoal[i], 0, 1)
	groovyTween.tween_property($Board/plainBG, "modulate", colorGoal, 2)
	groovyTween.tween_callback(updateTween)

func snap(x=-1, y=-1):
	if x == -1:
		x = currentPositionX
		y = currentPositionY
	if not board[x][y]:
		return
	grabPiece(x, y).position = Vector2(positions.x[currentPositionX], positions.y[currentPositionY])

func clickReaction(release=false):
	if turn != playerId or not toPlay or not activeGame or spectate:
		deselect()
		return
	if gameOn == false or (timeline != len(history)-1 and len(history) > 0):
		return
	if currentPiece == 0:
		select()
	else:
		movingPositionX = findX()
		movingPositionY = findY()
		if movingPositionX not in range(4) or movingPositionY not in range(8):
			return
		if movingPositionX == currentPositionX and movingPositionY == currentPositionY:
			if release:
				if releaseCount > 1:
					deselect()
			else:
				dragging = true
			return
		if $Board.has_node('LM' + str(movingPositionX) + str(movingPositionY)):
			move()
		else:
			if release:
				gl.sound(audio, 'res://audio/Error.mp3')
				return
			select()

func rightClickReaction():
	var moveSelectionX = findX()
	var moveSelectionY = findY()
	var sameSquare = moveSelectionX == currentSelectionX and moveSelectionY == currentSelectionY
	if sameSquare:
		var selectionName = 'circle' + str(currentSelectionX) + str(currentSelectionY)
		var selectionExists = $Board/Selections.has_node(selectionName)
		if not selectionExists:
			gl.popSprite($Board/Selections,
				Vector2(positions.x[currentSelectionX], positions.y[currentSelectionY]),
				'res://assets/circle.png', selectionName)
		else:
			$Board/Selections.get_node(selectionName).free()
	else:
		var selectionName = 'arrow' + str(currentSelectionX) + str(currentSelectionY) + str(moveSelectionX) + str(moveSelectionY)
		var selectionExists = $Board/Selections.has_node(selectionName)
		var buttPosition = Vector2(positions.x[currentSelectionX], positions.y[currentSelectionY])
		var headPosition = Vector2(positions.x[moveSelectionX], positions.y[moveSelectionY])
		var angle = (headPosition - buttPosition).angle()
		if not selectionExists:
			var selection = gl.popArrow($Board/Selections, selectionName,
				buttPosition, headPosition)
			selection.rotation = angle
		else:
			$Board/Selections.get_node(selectionName).free()

func clear_selection():
	for child in $Board/Selections.get_children():
		child.free()

func _on_board_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if Input.is_action_just_pressed('rightMouse'):
			currentSelectionX = findX()
			currentSelectionY = findY()
		elif Input.is_action_just_released('rightMouse'):
			if Input.is_action_pressed("leftMouse"):
				return
			rightClickReaction()
		elif Input.is_action_just_pressed("leftMouse"):
			$Board/ChatSp/Messagebox.release_focus()
			clear_selection()
			clickReaction()

func _transfer_board():
	var clockArray = [clockOn, clockCount]
	rpc("transfer_board", clockArray, lastMove, systemId, systemPassword)

@rpc('any_peer', 'call_remote', 'reliable', 0)
func transfer_board(_1, _2, _3, _4):
	pass

func getScore(s):
	var score = 0
	for l in s:
		score += strToScore[l]
	return score

func showTimes():
	if not len(players):
		return
	var strTimes = []
	for t in range(min(len(players), 2)):
		if timeHistory[-1][t] == -1:
			strTimes.append('Inf')
			continue
		var realTime = timeHistory[timeline][t]
		if activeGame or timeline == len(history)-1:
			realTime = $Board.get_node('Timer' + str(t)).time_left
		if t == playerId and lowerThan15 and realTime >= 25:
			lowerThan15 = false
		strTimes.append(str(floor(realTime / 60)) + ':' + "%02d" % (int(realTime) % 60)
		+ '.' + "%02d" % int((realTime - int(realTime)) * 100))
		if realTime < 15:
			if t == 0 and not lowerThan15 and len(moveHistory):
				lowerThan15 = true
				gl.sound(clockAudio, 'res://audio/ClockLow.mp3')
			$Board.get_node('Time' + str(t)).modulate = Color(1, 0.3, 0.3)
		else:
			$Board.get_node('Time' + str(t)).modulate = Color(1, 1, 1)
	if playerId == 1:
		strTimes.reverse()
	$Board/Time0.text = '[right]' + strTimes[playerId] + '[/right]'
	if len(players) > 1:
		$Board/Time1.text = '[right]' + strTimes[abs(playerId-1)] + '[/right]'

@rpc('any_peer', 'call_remote', 'reliable', 0)
func transfer_move(newClockHistory, newMoveHistory, newCaptureHistory, newTimeHistory,
	newTurn, newMessages, newActiveGame, newHistory, newPlayers, serverPaused, newClockOn, newIncrement):
	deselect()
	if playerId == -1:
		return
	if newPlayers[playerId]['name'] != systemId:
		flip()
	players = newPlayers
	turn = newTurn
	$Board/Name0.text = '[left]' + str(players[playerId]['name']) + '[/left]'
	$Board/Score0.text = '[left]' + str(players[playerId]['score']) + '[/left]'
	if abs(playerId-1) < len(players):
		$Board/Name1.text = '[left]' + str(players[abs(playerId-1)]['name']) + '[/left]'
		$Board/Score1.text = '[left]' + str(players[abs(playerId-1)]['score']) + '[/left]'
	for t in range(min(len(players), 2)):
		var it = t
		if playerId == 1:
			it = abs(t-1)
		$Board.get_node('Timer' + str(it)).wait_time = max(newTimeHistory[-1][t], 0.001)
		$Board.get_node('Timer' + str(it)).paused = true
		$Board.get_node('Timer' + str(it)).start()
	captureHistory = newCaptureHistory
	clockHistory = newClockHistory
	captures = captureHistory[len(captureHistory)-1]
	clockCount = clockHistory[len(clockHistory)-1]
	showTimes()
	if len(newMoveHistory):
		lastMove = newMoveHistory[-1]
		if len(players) > 1:
			for t in range(2):
				$Board.get_node('Timer' + str(t)).paused = true
			if newActiveGame:
				$Board.get_node('Timer' + str({true: 0, false: 1}[newTurn == playerId])).paused = false
	var oldClockOn = clockOn
	var oldHistoryLength = len(history)
	moveHistory = newMoveHistory
	timeHistory = newTimeHistory
	history = newHistory
	board = history[-1]
	clockOn = newClockOn
	clockJustStarted = false
	if clockOn:
		if newActiveGame:
			if clockCount > 3:
				if not oldClockOn:
					gl.sound(clockAudio, 'res://audio/ClockStart.mp3')
			else:
				gl.sound(clockAudio, 'res://audio/ClockLow.mp3')
			if clockCount == 7:
				clockJustStarted = true
	if not newActiveGame:
		get_window().title = "Martian Chess"
		$Board/Dancer.visible = false
		lowerThan15 = true
	else:
		$Board/Dancer.visible = true
		if turn == playerId:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
				DisplayServer.window_request_attention()
			$Board/Dancer.position.y = 605
			get_window().title = "Martian Chess (YOUR TURN)"
			toPlay = true
		else:
			$Board/Dancer.position.y = 28
			get_window().title = "Martian Chess"
	activeGame = newActiveGame
	rememberIncrement = newIncrement
	var slide_move = []
	if len(moveHistory) and playerId == turn and oldHistoryLength != len(history):
		slide_move = moveHistory[-1]
	change_timeline(len(history)-1, true, slide_move)
	update_chat(newMessages)
	if serverPaused:
		gl.popSprite($Board, Vector2(246, 316), 'res://assets/serverPaused.png', 'serverPause', Vector2(1, 1))
	else:
		if $Board.has_node('serverPause'):
			$Board.get_node('serverPause').free()

@rpc('any_peer', 'call_remote', 'reliable', 0)
func send_winner(id):
	if spectate or playerId == -1:
		return
	$Board/Timer0.paused = true
	$Board/Timer1.paused = true
	gl.sound(audio, 'res://audio/Notify.mp3')
	audio.play()
	holderVar = 'You Lost.'
	if id == playerId:
		holderVar = 'You Won!'
	gl.dialog($Board, holderVar)
	activeGame = false
	for child in $Board.get_children():
		if 'LM' in str(child.name) or 'selection' in str(child.name):
			child.free()

func move():
	if not toPlay:
		return
	if board[movingPositionX][movingPositionY]:
		var enemySide = YSide(movingPositionY) != playerId
		if enemySide:
			if clockOn == true:
				clockCount = 7
				clock.region_rect.position.x = 0
			grabPiece(movingPositionX, movingPositionY).free()
			board[movingPositionX][movingPositionY] = 0
		else:
			holderVar = spotPiece(currentPositionX, currentPositionY) + spotPiece(movingPositionX, movingPositionY)
			holderVar -= 1
			grabPiece(movingPositionX, movingPositionY).free()
			board[movingPositionX][movingPositionY] = 0
			grabPiece(currentPositionX, currentPositionY).region_rect.position.x = (2 - holderVar) * 64
	if clockOn == true:
		clockCount -= 1
		clock.region_rect.position.x += 64
	if YSide(currentPositionY) != YSide(movingPositionY):
		if playerId != 1:
			grabPiece(currentPositionX, currentPositionY).position.y -= 4
		else:
			grabPiece(currentPositionX, currentPositionY).position.y += 4
	board[movingPositionX][movingPositionY] = board[currentPositionX][currentPositionY]
	board[currentPositionX][currentPositionY] = 0
	deselect()
	lastMove = [currentPositionX, currentPositionY, movingPositionX, movingPositionY]
	_transfer_board()
	toPlay = false
	if YSide(movingPositionY) and YSide(currentPositionY):
		for x in range(4):
			for y in range(4):
				if board[x][y]:
					return
		gameOn = false

func deselect():
	currentPiece = 0
	for child in $Board.get_children():
		if 'LM' in str(child.name):
			child.free()
	if $Board.has_node('selection'):
		$Board.get_node('selection').free()

func countPieces(side, value):
	var amount = 0
	var y_range = range(4 * (side), 4 * (side+1))
	if side == -1:
		y_range = range(8)
	for x in range(4):
		for y in y_range:
			if board[x][y] == value:
				amount += 1
	return amount

func checkMove(pos):
	var actualPos = Vector2(positions.x[pos.x], positions.y[pos.y])
	var value = spotPiece(pos.x, pos.y)
	if value:
		var sameSide = YSide(pos.y) == playerId
		if sameSide:
			var newValue = currentPiece + value
			if newValue > 3:
				return true
			if countPieces(-1, newValue) == 6:
				return true
			if countPieces(playerId, newValue):
				return true
		gl.popSprite($Board, actualPos, 'res://assets/capture.png', 'LM' + str(pos.x) + str(pos.y))
		return true
	else:
		gl.popSprite($Board, actualPos, 'res://assets/move.png', 'LM' + str(pos.x) + str(pos.y))
	return false

func select():
	var reselect = currentPiece
	currentPositionX = findX()
	currentPositionY = findY()
	if YSide(currentPositionY) == playerId:
		currentPiece = spotPiece(currentPositionX, currentPositionY)
		if currentPiece:
			for child in $Board.get_children():
				if 'LM' in str(child.name):
					child.free()
			if currentPiece == 1:
				for i in range(-1, 2, 2):
					for j in range(-1, 2, 2):
						var legalMoveBoardPos = Vector2(currentPositionX+i, currentPositionY+j)
						if int(legalMoveBoardPos.x) not in range(4) or int(legalMoveBoardPos.y) not in range(8):
							break
						checkMove(legalMoveBoardPos)
			elif currentPiece == 2:
				for k in 'xy':
					for j in range(-1, 2, 2):
						for i in range(1 * j, 3 * j, j):
							var legalMoveBoardPos = Vector2(currentPositionX, currentPositionY)
							legalMoveBoardPos[k] += i
							if int(legalMoveBoardPos.x) not in range(4) or int(legalMoveBoardPos.y) not in range(8):
								break
							if checkMove(legalMoveBoardPos):
								break
			elif currentPiece == 3:
				for l in range(2):
					for k in range(2):
						for j in range(-1, 2, 2):
							for i in range(1 * j, 8 * j, j):
								var legalMoveBoardPos = Vector2(currentPositionX, currentPositionY)
								legalMoveBoardPos['xy'[k]] += i
								legalMoveBoardPos['xy'[abs(k-1)]] += i * l * {1: -1, 0: 1}[k]
								if int(legalMoveBoardPos.x) not in range(4) or int(legalMoveBoardPos.y) not in range(8):
									break
								if checkMove(legalMoveBoardPos):
									break
			var cantRedo = 'LM' + str(lastMove[0]) + str(lastMove[1])
			if currentPositionX == lastMove[2] and currentPositionY == lastMove[3] and $Board.has_node(cantRedo):
				$Board.get_node(cantRedo).free()
			gl.popSprite($Board, grabPiece(currentPositionX, currentPositionY).position, 'res://assets/selection.png', 'selection')
	else:
		currentPiece = 0
	if not currentPiece:
		if reselect:
			gl.sound(audio, 'res://audio/Error.mp3')
		deselect()
	else:
		var currentObject = grabPiece(currentPositionX, currentPositionY)
		var curObjParent = currentObject.get_parent()
		curObjParent.move_child(currentObject, -1)
		dragging = true
		releaseCount = 0

func findX():
	var value = snapped(get_viewport().get_mouse_position().x - 112 - 34, 68) / 68
	if playerId == 1:
		value = 3 - value
	return value

func findY():
	holderVar = get_viewport().get_mouse_position().y - 44 - 34
	if holderVar > 258:
		holderVar -= 10
	var value = snapped(holderVar, 68) / 68
	if playerId != 1:
		value = 7 - value
	return value

func YSide(y):
	var yBool = y > 3
	return {false: 0, true: 1}[yBool]

func grabPiece(locX, locY):
	var node_name = "Board/Piece" + str(locX) + str(locY)
	if not has_node(node_name):
		return null
	else:
		return get_node(node_name)

func spotPiece(locX, locY):
	if not board[locX][locY]:
		return 0
	return 4 - (grabPiece(locX, locY).region_rect.position.x / 64 + 1)

func save_inputs(inputs):
	var file = FileAccess.open("user://inputs.dat", FileAccess.WRITE)
	file.store_line(JSON.stringify(inputs))

func load_inputs():
	var file = FileAccess.open("user://inputs.dat", FileAccess.READ)
	if file:
		var inputs = JSON.parse_string(file.get_line())
		if inputs:
			if Time.get_unix_time_from_system() - inputs["time"] < 36000:
				$Body/Username.text = inputs["usernameInquery"]
				$Body/ServerIP.text = inputs["IPInquery"]
				$Body/Port.text = inputs["portInquery"]
				$Body/Username.grab_focus()
				if inputs["IPInquery"]:
					_on_connect_pressed()
				inputs["time"] = Time.get_unix_time_from_system()
				save_inputs(inputs)
			else:
				save_inputs({})

func _on_enter_pressed() -> void:
	if not gl.connected:
		gl.dialog(surrogate, 'Not Yet Connected')
		return
	var usernameInquery = $Body/Username.text
	var passwordInquery = $Body/Password.text
	var serverInquery = $Body/Server.text
	var IPInquery = $Body/ServerIP.text
	var portInquery = $Body/Port.text
	if not usernameInquery:
		usernameInquery = str(OS.get_unique_id()).substr(0, 6)
	if len(usernameInquery) > 20:
		gl.dialog(surrogate, 'Name Too Long')
		return
	systemId = usernameInquery
	systemPassword = passwordInquery
	save_inputs({
		"usernameInquery": usernameInquery,
		"IPInquery": IPInquery,
		"portInquery": portInquery,
		"time": Time.get_unix_time_from_system()
	})
	rpc('request_entry', usernameInquery, passwordInquery, serverInquery, OS.get_unique_id(), VERSION)

func _on_clock_input_event(_viewport, _event, _shape_idx) -> void:
	if Input.is_action_just_pressed ("leftMouse") or _event is int:
		if turn == playerId and clockOn == false and (timeline == len(history)-1 or len(history) == 0):
			clockOn = true
			clock.material = ShaderMaterial.new()
			clock.material.shader = load("res://assets/shaders/Invert.gdshader")
			gl.sound(clockAudio, 'res://audio/ClockStart.mp3')
			rpc("clock_on", playerId, systemPassword)

@rpc
func leave_single(id):
	if id == systemId:
		get_tree().quit()

@rpc
func _hand_password(pw):
	password = pw
	gl.dialog(surrogate, "Server Pass Updated")

@rpc('any_peer', 'call_remote', 'reliable', 0)
func clock_on(_1, _2):
	pass

@rpc('any_peer', 'call_remote', 'reliable', 0)
func request_entry(_1, _2, _3, _4, _5):
	pass

@rpc
func inquery_result(un, id, err):
	if systemId != un:
		return
	if err:
		systemId = ''
		systemPassword = ''
		gl.dialog(surrogate, err)
	else:
		playerId = id
		if playerId == -1:
			playerId = 0
			spectate = true
		ogSettings()
		if is_instance_valid($Body):
			gl.goToBoard(self)
			$Board/ChatSp/Messagebox.grab_focus()
			if systemId.to_lower() == 'mat':
				getGroovy()

@rpc
func tell(info):
	gl.dialog($Board, info)

func flip():
	if spectate or playerId == -1:
		return
	playerId = abs(playerId - 1)
	invertPositions()
	ogSettings()

@rpc('any_peer', 'call_remote', 'reliable', 0)
func message_sent(_1, _2, _3):
	pass

func _on_messagebox_text_submitted(new_text: String) -> void:
	if len(new_text) > 300:
		gl.dialog($Board, 'Message too Long.')
		return
	$Board/ChatSp/Messagebox.text = ''
	rpc("message_sent", systemId, systemPassword, new_text)

@rpc
func update_chat(messages):
	var allChat = ''
	for msg in messages:
		allChat += msg + '\n'
	$Board/ChatSp/Chat.text = allChat

@rpc('any_peer', 'call_remote', 'reliable', 0)
func resign(_1, _2):
	pass

@rpc('any_peer', 'call_remote', 'reliable', 0)
func request_new_game(_1, _2, _3, _4):
	pass

@rpc('any_peer', 'call_remote', 'reliable', 0)
func start_new_game(_1, _2, _3):
	pass

@rpc('any_peer', 'call_remote', 'reliable', 0)
func claim_abandon_victory(_1, _2,):
	pass

func confirm_resignation():
	rpc('resign', playerId, systemPassword)

func _on_flag_input_event(_viewport, _event, _shape_idx) -> void:
	if Input.is_action_just_pressed ("leftMouse"):
		if not activeGame or spectate or not len(moveHistory):
			return
		var confirmNode = gl.confirm($Board, 'Are you sure you want to forfeit?')
		confirmNode.confirmed.connect(confirm_resignation)

func confirm_request():
	if has_node('NewGame'):
		var minutes = clamp(str($NewGame/Window/Minutes.text).to_float(), 0, 180)
		var increment = clamp(str($NewGame/Window/Increment.text).to_int(), 0, 180)
		if minutes and minutes < 0.25:
			$NewGame/Window.queue_free()
			gl.dialog($Board, 'Lowest time allowed is 0.25')
			return
		rpc('request_new_game', playerId, systemPassword, minutes, increment)
		$NewGame/Window.queue_free()

func request_close():
	$NewGame/Window.queue_free()

func minutes_submitted(_1):
	$NewGame/Window/Increment.grab_focus()

func increment_submitted(_1):
	confirm_request()

func _on_new_game_input_event(_viewport, _event, _shape_idx) -> void:
	if Input.is_action_just_pressed ("leftMouse"):
		if spectate:
			return
		if Time.get_unix_time_from_system() - players[playerId]['lastRequest'] < 30:
			gl.dialog($Board, "You're on cooldown.")
			return
		if has_node('NewGame'):
			get_node('NewGame').free()
		var requestScene = preload('res://scenes/new_game_request.tscn').instantiate()
		if timeHistory[0][0] != -1:
			requestScene.get_node('Window/Minutes').text = str(timeHistory[0][0]/60)
		if rememberIncrement:
			requestScene.get_node('Window/Increment').text = str(rememberIncrement)
		add_child(requestScene)
		requestScene.get_node('Window/Minutes').grab_focus()
		requestScene.get_node('Window/Minutes').text_submitted.connect(minutes_submitted)
		requestScene.get_node('Window/Increment').text_submitted.connect(increment_submitted)
		requestScene.get_node('Window').close_requested.connect(request_close)
		requestScene.get_node('Window/Request').pressed.connect(confirm_request)

func statusUpdate():
	var statusAssociate = {false: Color(0.75, 0.3, 0.3), true: Color(0.3, 0.75, 0.3)}
	$Board/Status0.modulate = statusAssociate[true]
	if len(players) > 1:
		$Board/Status1.modulate = statusAssociate[len(players[abs(playerId-1)]['sessionId']) > 0]
	else:
		$Board/Status1.modulate = statusAssociate[false]

func reconstruct_board(toSlide=[]):
	if playerId == -1:
		return
	if not len(history):
		history = [board.duplicate(true)]
	var simulatedBoard = history[timeline]
	var simulatedCaptures = captureHistory[timeline]
	var simulatedClock = clockHistory[timeline]
	for child in get_node('Board').get_children():
		if is_instance_valid(child) and 'Piece' in str(child.name):
			child.free()
	for x in range(len(simulatedBoard)):
		for y in range(len(simulatedBoard[x])):
			if simulatedBoard[x][y]:
				var sprite = Sprite2D.new()
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.texture = load('res://assets/Assets.png')
				sprite.region_enabled = true
				sprite.region_rect.size = Vector2(64, 64)
				sprite.region_rect.position.x = 64 * abs(simulatedBoard[x][y] - 3)
				sprite.position = Vector2(positions.x[x], positions.y[y])
				sprite.name = 'Piece' + str(x) + str(y)
				$Board.add_child(sprite)
	var brightColor = {true: Color(0, 0, 0, 0), false: Color(0.4, 0.4, 0.4, 0)}
	for i in range(2):
		var it = i
		if playerId == 1:
			it = abs(it-1)
		$Board.get_node('Holder' + str(it)).modulate = holderColors[i] - brightColor[i == turn]
	var dif = getScore(simulatedCaptures[playerId]) - getScore(simulatedCaptures[abs(playerId-1)])
	var color = 'green'
	if dif > 0:
		dif = '+' + str(dif)
	elif dif < 0:
		color = 'red'
	else:
		color = 'white'
	label.text = '[right][color=' + color + ']' + str(dif) + '[/color][/right]'
	var playerScores = []
	for p in range(min(len(players), 2)):
		var p_score = getScore(simulatedCaptures[p])
		playerScores.append(p_score)
		var pieceY = {abs(playerId-1): 56, playerId: 576}[p]
		var changeRate = 15 * {abs(playerId-1): 1, playerId: -1}[p]
		for child in $Board.get_children():
			if ('Capture' + str(p)) in str(child.name):
				child.free()
		for l in strToScore:
			for i in range(simulatedCaptures[p].count(l)):
				var sp = Sprite2D.new()
				sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sp.position = Vector2(98, pieceY)
				sp.texture = load("res://assets/Assets.png")
				sp.scale = Vector2(0.5, 0.5)
				sp.region_enabled = true
				sp.region_rect.size = Vector2(64, 64)
				sp.region_rect.position = Vector2(192 - (strToScore[l] * 64), 0)
				sp.name = 'Capture' + str(p) + str(strToScore[l]) + str(i)
				$Board.add_child(sp)
				if p == playerId:
					$Board.move_child(sp, 1)
				pieceY += changeRate
	clock.region_rect.position.x = 448 - (simulatedClock * 64)
	if simulatedClock < 7 or (clockJustStarted and timeline == len(history)-1):
		if not clock.material:
			clock.material = ShaderMaterial.new()
			clock.material.shader = load("res://assets/shaders/Invert.gdshader")
	else:
		clock.material = null
	if toSlide:
		var slidingPiece = grabPiece(toSlide[2], toSlide[3])
		if slidingPiece:
			slidingPiece.position = Vector2(positions.x[toSlide[0]], positions.y[toSlide[1]])
			var slidingTween = create_tween()
			slidingTween.tween_property(slidingPiece, "position", Vector2(positions.x[toSlide[2]], positions.y[toSlide[3]]), 0.15)
			slidingTween.tween_callback(slidingTween.kill)
	statusUpdate()

func change_timeline(value, to_set=false, to_slide=[]):
	var oldTimeline = timeline
	var doSound = true
	if to_set:
		timeline = value
	else:
		timeline += value
	if timeline > len(history)-1 and len(history) and not to_set:
		doSound = false
	timeline = clamp(timeline, 0, max(len(history)-1, 0))
	if $Board.has_node('moved'):
		$Board.get_node('moved').free()
		$Board.get_node('moved2').free()
	deselect()
	if timeline > 0:
		gl.popSprite($Board, Vector2(positions.x[moveHistory[timeline-1][0]],
			positions.y[moveHistory[timeline-1][1]]), 'res://assets/moved.png', 'moved')
		gl.popSprite($Board, Vector2(positions.x[moveHistory[timeline-1][2]],
			positions.y[moveHistory[timeline-1][3]]), 'res://assets/moved.png', 'moved2')
	reconstruct_board(to_slide)
	if value > 0 and oldTimeline != timeline:
		clear_selection()
		var simMove = moveHistory[timeline-1]
		var isCapture = history[timeline-1][simMove[0]][simMove[1]] and history[timeline-1][simMove[2]][simMove[3]]
		if doSound:
			if isCapture:
				gl.sound(audio, 'res://audio/Capture.mp3')
			else:
				gl.sound(audio, 'res://audio/Move.mp3')

@rpc('any_peer', 'call_remote', 'reliable', 0)
func request_takeback(_1, _2):
	pass

@rpc('any_peer', 'call_remote', 'reliable', 0)
func confirm_takeback(_1, _2, _3):
	pass

func confirm_request_takeback():
	rpc('request_takeback', playerId, systemPassword)

func _on__input_event(_viewport, _event, shape_idx) -> void:
	if Input.is_action_just_pressed("leftMouse") or _event is int:
		if shape_idx == 0:
			if spectate or len(moveHistory) - playerId < 1:
				return
			if not activeGame:
				gl.dialog($Board, 'Game is Over')
				return
			var confirmNode = gl.confirm($Board, 'Request Takeback?')
			confirmNode.confirmed.connect(confirm_request_takeback)
			return
		if shape_idx == 3:
			change_timeline(len(history)-1, true)
			return
		var sm = []
		var value = {1: -1, 2: 1}[shape_idx]
		if value == -1:
			if timeline-1 >= 0 and timeline-1 < len(moveHistory):
				sm = moveHistory[timeline-1]
				sm = [sm[2], sm[3], sm[0], sm[1]]
		elif value == 1:
			if timeline >= 0 and timeline < len(moveHistory):
				sm = moveHistory[timeline]
		change_timeline(value, false, sm)

func _on_username_text_submitted(_new_text: String) -> void:
	$Body/Password.grab_focus()

func _on_password_text_submitted(_new_text: String) -> void:
	$Body/Server.grab_focus()

func _on_server_text_submitted(_new_text: String) -> void:
	_on_enter_pressed()

func _on_mute_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int) -> void:
	if Input.is_action_just_pressed("leftMouse"):
		if AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")):
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
			$Board/Mute/Mute.tooltip_text = 'Mute'
			$Board/Mute/Mute.modulate = Color(1, 1, 1)
		else:
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
			$Board/Mute/Mute.tooltip_text = 'Unmute'
			$Board/Mute/Mute.modulate = Color(0.4, 0.4, 0.4)

func _on_messagebox_text_changed(new_text: String) -> void:
	if Time.get_unix_time_from_system() - 5 > lastTyping and len(new_text) > 1:
		rpc('imTyping', systemId, systemPassword)
		lastTyping = Time.get_unix_time_from_system()

@rpc('any_peer', 'call_remote', 'reliable', 0)
func imTyping(_1, _2):
	pass

@rpc()
func isTyping(id, to):
	var msg = id + ' is Typing[wave]...[/wave]'
	if to:
		if id != systemId:
			$Board/isTyping.text = msg
			$Board/isTyping.visible = true
	elif $Board/isTyping.text == msg:
		$Board/isTyping.visible = false
	$Board/Typing.start()

func _on_typing_timeout() -> void:
	$Board/isTyping.visible = false

func _on_connect_pressed() -> void:
	gl.serverIP = str($Body/ServerIP.text)
	gl.serverPort = str($Body/Port.text).to_int()
	gl.rpc_connections(surrogate)

func _on_server_ip_text_submitted(_new_text: String) -> void:
	$Body/Port.grab_focus()

func _on_port_text_submitted(_new_text: String) -> void:
	_on_connect_pressed()
	$Body/Username.grab_focus()
