extends Node2D
@onready var text = null
@onready var password = ""
@onready var serverPort = 31400
const serverIP = "188.129.239.219"
const maxPlayers = 10
const VERSION = '1.4.1'
@onready var surrogate = $Body
@onready var players = []
@onready var playerInfo = []
@onready var messages = []
@onready var colors = [
	"White",
	"Yellow",
	"Cyan",
	"Lime",
	"Orange",
	"Pink",
	"Silver",
	"Gold",
	"Magenta",
	"Aqua",
	"Navajowhite",
	"LightGreen",
	"LightCoral",
	"Wheat",
	"PaleGreen",
	"LightYellow",
	"LightPink",
	"Deeppink",
	"Khaki",
	"Lavender"
]

@onready var valueToStr = {1: 'P', 2: 'D', 3: 'Q'}
@onready var strToValue = {'P': 1, 'D': 2, 'Q': 3}
@onready var board = []
@onready var lastMove = []
@onready var clock = false
@onready var turn = 0
@onready var moveCount = 0
@onready var isCapture = false
@onready var deviceControl = true
@onready var activeGame = true
@onready var playerScores = [0, 0]
@onready var moveHistory = []
@onready var captureHistory = []
@onready var clockHistory = []
@onready var timeHistory = []
@onready var history = []
@onready var startTime = -1
@onready var incrementTime = 0
@onready var paused = false
@onready var lastRequester = -1
@onready var requestedTime = {}
@onready var lastTakebackRequester = -1
@onready var clockActivation = -1


func ogSettings():
	for t in range(2):
		if startTime != -1:
			$Body.get_node('Timer' + str(t)).wait_time = startTime
		$Body.get_node('Timer' + str(t)).paused = true
		$Body.get_node('Timer' + str(t)).start()
	board = [
		[0, 0, 0, 0, 0, 2, 3, 3],
		[2, 1, 1, 0, 0, 1, 2, 3],
		[3, 2, 1, 0, 0, 1, 1, 2],
		[3, 3, 2, 0, 0, 0, 0, 0]
	]
	lastMove = []
	clock = false
	turn = 0
	moveCount = 0
	isCapture = false
	activeGame = true
	playerScores = [0, 0]
	history = [board.duplicate(true)]
	captureHistory = [['' , '']]
	clockHistory = [7]
	moveHistory = []
	timeHistory = [[startTime, startTime]]
	clockActivation = -1

func _ready():
	$Body/LineEdit.grab_focus()
	ogSettings()
	colors.shuffle()

func _on_peer_disconnected(peer_id):
	var disconnectedName = ''
	var disconnectedId = 0
	for p in range(len(playerInfo)):
		if peer_id in playerInfo[p]['sessionId']:
			disconnectedName = playerInfo[p]['name']
			disconnectedId = p
			playerInfo[p]['sessionId'].erase(peer_id)
			_transfer_move()
	if disconnectedName:
		if not len(playerInfo[disconnectedId]['sessionId']):
			if (disconnectedId < 2 and len(moveHistory) > 1 and activeGame
				and len(playerInfo[abs(disconnectedId-1)]['sessionId'])):
				killURL(['acceptabandonvictory'])
				_update_chat(2, '\n[center]' + disconnectedName +
				' Left[url=acceptabandonvictory]\nClaim Victory?[/url][/center]\n')
			else:
				_update_chat(2, disconnectedName + ' Left')

func create_server() -> void:
	var server = ENetMultiplayerPeer.new()
	server.create_server(serverPort, maxPlayers)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.multiplayer_peer = server

func _on_button_button_down():
	pass

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null

# @rpc
# func leave_OS():
# 	pass

@rpc
func leave_single():
	pass

@rpc
func _hand_password(pw):
	password = pw

func hand_password(pw):
	_hand_password(pw)
	rpc("_hand_password", pw)

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

func checkMove(cx, cy, x, y, id):
	var currentPiece = board[cx][cy]
	var value = board[x][y]
	if value:
		var sameSide = (id == 0 and y < 4) or (id == 1 and y > 3)
		if sameSide:
			var newValue = currentPiece + value
			if newValue > 3:
				return false
			if countPieces(abs(id-1), newValue) == 6:
				return false
			if countPieces(id, newValue):
				return false
		return 'capture' # Capture on X Y
	else:
		return 'move' # Move on X Y

func getAllLegalMoves(x, y, id):
	var legalMoves = []
	var currentPiece = board[x][y]
	if currentPiece == 1:
		for i in range(-1, 2, 2):
			for j in range(-1, 2, 2):
				var lmx = x+i
				var lmy = y+j
				if int(lmx) not in range(4) or int(lmy) not in range(8):
					break
				var result = checkMove(x, y, lmx, lmy, id)
				if not result:
					continue
				else:
					legalMoves.append(str(lmx) + str(lmy))
				if result == 'capture':
					continue
	elif currentPiece == 2:
		for k in 'xy':
			for j in range(-1, 2, 2):
				for i in range(1 * j, 3 * j, j):
					var lm = Vector2(x, y)
					lm[k] += i
					if int(lm.x) not in range(4) or int(lm.y) not in range(8):
						break
					var result = checkMove(x, y, lm.x, lm.y, id)
					if not result:
						continue
					else:
						legalMoves.append(str(lm.x) + str(lm.y))
					if result == 'capture':
						continue
	elif currentPiece == 3:
		for l in range(2):
			for k in range(2):
				for j in range(-1, 2, 2):
					for i in range(1 * j, 8 * j, j):
						var lm = Vector2(x, y)
						lm['xy'[k]] += i
						lm['xy'[abs(k-1)]] += i * l * {1: -1, 0: 1}[k]
						if int(lm.x) not in range(4) or int(lm.y) not in range(8):
							break
						var result = checkMove(x, y, lm.x, lm.y, id)
						if not result:
							continue
						else:
							legalMoves.append(str(lm.x) + str(lm.y))
						if result == 'capture':
							continue
	return legalMoves

func isLegalMove(lm, id):
	var movingPiece = board[lm[0]][lm[1]]
	var lastMoveVerification = (not len(lastMove) or not (lm[0] == lastMove[2] and lm[1] == lastMove[3]
	and lm[2] == lastMove[0] and lm[3] == lastMove[1]))
	if (not movingPiece or (id == 0 and lm[1] > 3) or (id == 1 and lm[1] < 4) or turn != id or not activeGame
		or not lastMoveVerification):
		return false
	if (str(lm[2]) + str(lm[3])) not in getAllLegalMoves(lm[0], lm[1], id):
		return false
	return true

@rpc('any_peer', 'call_remote', 'reliable', 0)
func transfer_board(newClock, newLastMove, id, pw):
	isCapture = false
	var oldId = players.find(id)
	if oldId != -1:
		if not isLegalMove(newLastMove, oldId) or playerInfo[oldId]['password'] != pw or paused:
			_transfer_move()
			return
		moveCount += 1
		if lastRequester != -1 and lastRequester == abs(oldId-1):
			lastRequester = -1
			killURL(['newgameaccept', 'newgamedecline'])
		if lastTakebackRequester != -1:
			lastTakebackRequester = -1
			killURL(['takebackaccept', 'takebackdecline'])
		if startTime != -1:
			$Body.get_node('Timer' + str(oldId)).paused = true
			$Body.get_node('Timer' + str(oldId)).wait_time = $Body.get_node('Timer' + str(oldId)).time_left + incrementTime
			$Body.get_node('Timer' + str(oldId)).start()
			if len(players) > 1:
				$Body.get_node('Timer' + str(abs(oldId-1))).paused = false
		var clockCount = clockHistory[-1]
		var captures = captureHistory[-1].duplicate()
		clock = newClock[0]
		clockCount = newClock[1]
		lastMove = newLastMove
		var lastMove_dupe = lastMove.duplicate()
		var moved = board[lastMove_dupe[0]][lastMove_dupe[1]]
		var to = board[lastMove_dupe[2]][lastMove_dupe[3]]
		if to:
			var sameSide = (lastMove_dupe[3] < 4 and lastMove_dupe[1] < 4) or (lastMove_dupe[3] > 3 and lastMove_dupe[1] > 3)
			if not sameSide:
				captures[oldId] += valueToStr[to]
				playerScores[oldId] += to
				isCapture = true
			else:
				moved = moved + to
		board[lastMove_dupe[2]][lastMove_dupe[3]] = moved
		board[lastMove_dupe[0]][lastMove_dupe[1]] = 0
		turn = abs(oldId-1)
		var end = true
		for x in range(4):
			for y in range(oldId*4, oldId*4+4):
				if board[x][y] != 0:
					end = false
					break
		if clockCount <= 0:
			end = true
		if end:
			var winner = {false: 0, true: 1}[playerScores[1] > playerScores[0]]
			if playerScores[0] == playerScores[1]:
				winner = oldId
			_update_chat(2, players[winner] + ' Wins!')
			_send_winner(winner)
		history.append(board.duplicate(true))
		moveHistory.append(lastMove.duplicate(true))
		captureHistory.append(captures)
		clockHistory.append(clockCount)
		update_time()
	_transfer_move()

func _transfer_move():
	rpc("transfer_move", clockHistory, moveHistory, captureHistory, timeHistory,
		turn, messages, activeGame, history, playerInfo, paused, clock, incrementTime)

@rpc('any_peer', 'call_remote', 'reliable', 0)
func transfer_move():
	pass

@rpc('any_peer', 'call_remote', 'reliable', 0)
func clock_on(id, pw):
	if playerInfo[id]['password'] != pw or paused:
		_transfer_move()
		return
	clock = true
	clockActivation = len(history)
	_transfer_move()
	_update_chat(2, 'The Clock has been Called')

func sherefIt():
	var rng = RandomNumberGenerator.new()
	$Sheref.wait_time = rng.randf_range(60, 240)
	$Sheref.start()

@rpc('any_peer', 'call_remote', 'reliable', 0)
func request_entry(un, ps, sr, uni, ver):
	var err = ''
	un = un.replace('[', '[lb]')
	if sr != password:
		err = 'Incorrect Server'
	if password == '':
		err = 'Awaiting Server to Set Pass'
	if deviceControl:
		for p in playerInfo:
			if 'deviceId' in p and p.deviceId == uni and un != p['name']:
				err = 'One Player per Device Rule is true'
	if ver != VERSION:
		err = 'Server is on ' + str(VERSION) + ' - Not ' + str(ver)
	if un in players and not err:
		if playerInfo[players.find(un)]['password'] != ps:
			err = 'Incorrect Password for ' + un
		else:
			playerInfo[players.find(un)]['sessionId'].append(multiplayer.get_remote_sender_id())
			killURL(['acceptabandonvictory'])
			var msg = un + ' Rejoined'
			if len(playerInfo[players.find(un)]['sessionId']) > 1:
				msg = un + ' Rejoined... Again.'
			_update_chat(2, msg)
	elif not err:
		if len(players) < 2:
			players.append(un)
			playerInfo.append( {
				'password': ps,
				'deviceId': uni,
				'name': un,
				'score': 0,
				'sessionId': [multiplayer.get_remote_sender_id()],
				'lastRequest': 0.0
			} )
			if un.to_lower() == 'sheref':
				sherefIt()
			_update_chat(2, un + ' has Joined!')
		else:
			playerInfo.append( {
				'password': ps,
				'deviceId': uni,
				'name': un,
				'sessionId': [multiplayer.get_remote_sender_id()]
			} )
			_update_chat(2, un + ' is Spectating!')
	rpc('inquery_result', un, players.find(un), err)
	if not err:
		_transfer_move()

@rpc
func inquery_result():
	pass

@rpc
func tell():
	pass

func _tell(info, updateChat=false):
	if updateChat:
		_update_chat(2, info)
	rpc('tell', info)

func dialog(t):
	for child in get_children():
		if child is AcceptDialog:
			child.free()
	var ad = AcceptDialog.new()
	ad.dialog_text = t
	ad.visible = true
	add_child(ad)
	ad.popup_centered()

func _update_chat(colorId, info, forceName=''):
	if info:
		var coloredInfo = '[color=' + colors[colorId] + ']' + info + '[/color]'
		if colorId != 2:
			var color = ''
			if -1 < colorId and colorId < len(players):
				color = colors[colorId]
			else:
				color = colors[3]
			var userName = players[colorId]
			if forceName:
				userName = forceName
			coloredInfo = "[color=" + color + "]" + userName + '[/color]: ' + info
		messages.append(coloredInfo)
	rpc('update_chat', messages)

@rpc('any_peer', 'call_remote', 'reliable', 0)
func send_winner():
	pass

@rpc
func update_chat():
	pass

@rpc('any_peer', 'call_remote', 'reliable', 0)
func message_sent(id, pw, msg):
	if playerInfo[players.find(id)]['password'] != pw:
		return
	var breakBBC = false
	var bracketCount = 0
	for l in msg:
		if l == '[':
			bracketCount += 1
		elif l == ']':
			bracketCount -= 1
			if bracketCount < 0:
				breakBBC = true
				break
	if bracketCount:
		breakBBC = true
	if breakBBC:
		msg = msg.replace('[', '[lb]')
	if not breakBBC:
		var regex = RegEx.new()
		regex.compile("\\[/?([a-zA-Z][a-zA-Z0-9]*)(?:[\\s=][^\\]]+)?\\]")
		var killTag = ['url', 'img']
		var order = []
		for result in regex.search_all(msg):
			var tag = result.get_string()
			var n = result.get_string(1)
			if n in killTag:
				continue
			if tag.begins_with("[/"):
				var lastTag = ''
				if len(order):
					lastTag = order[-1]
				if lastTag != n:
					killTag.append(n)
					while n in order:
						order.erase(n)
					continue
				else:
					order.remove_at(len(order)-1)
			else:
				order.append(n)
		order.reverse()
		for t in order:
			msg += '[/%s]' % [t]
		for t in killTag:
			msg = msg.replace('[%s' % [t], '[lb]%s' % [t])
			msg = msg.replace('[/%s' % [t], '[lb]/%s' % [t])
	if len(msg) > 300:
		return
	if not msg:
		return
	rpc('isTyping', id, false)
	_update_chat(players.find(id), msg, id)

func _on_check_button_toggled(toggled_on: bool) -> void:
	deviceControl = toggled_on
	var deviceIds = []
	if deviceControl:
		for p in playerInfo:
			if 'deviceId' in p:
				if p.deviceId in deviceIds:
					rpc('leave_single', p.name)
					return
				deviceIds.append(p.deviceId)

func _send_winner(id):
	if len(players) < 2:
		id = -1
	activeGame = false
	$Body/Timer0.paused = true
	$Body/Timer1.paused = true
	playerInfo[id]['score'] += 1
	_transfer_move()
	rpc('send_winner', id)

@rpc('any_peer', 'call_remote', 'reliable', 0)
func resign(id, pw):
	if playerInfo[id]['password'] != pw or paused:
		_transfer_move()
		return
	_update_chat(2, players[id] + ' Resigned')
	_send_winner(abs(id-1))

@rpc('any_peer', 'call_remote', 'reliable', 0)
func request_new_game(id, pw, mn, inc):
	if (playerInfo[id]['password'] != pw or paused
	or Time.get_unix_time_from_system() - playerInfo[id]['lastRequest'] < 30):
		_transfer_move()
		return
	playerInfo[id]['lastRequest'] = Time.get_unix_time_from_system()
	_transfer_move()
	requestedTime = {'time': mn, 'increment': inc}
	var strRequestedTime = str(mn) + ' | ' + str(inc)
	if not mn:
		strRequestedTime = 'Inf'
	if len(players) == 1:
		realStartNewGame()
		return
	lastRequester = id
	killURL(['newgameaccept', 'newgamedecline'])
	_update_chat(2, '\n[center]' + players[id] +
		' Requested\n[i]New Game[/i] (' + strRequestedTime +
		').\n[url=newgameaccept]Accept[/url]  /  [url=newgamedecline]Decline[/url][/center]\n')

func realStartNewGame():
	if len(players) > 1:
		var player0 = players[0]
		players[0] = players[1]
		players[1] = player0
		var playerInfo0 = playerInfo[0].duplicate(true)
		playerInfo[0] = playerInfo[1].duplicate(true)
		playerInfo[1] = playerInfo0
	ogSettings()
	change_time(requestedTime['time'], requestedTime['increment'])
	_transfer_move()

@rpc('any_peer', 'call_remote', 'reliable', 0)
func claim_abandon_victory(id, pw):
	if playerInfo[id]['password'] != pw or len(playerInfo[abs(id-1)]['sessionId']) or paused:
		return
	_update_chat(2, players[id] + ' Claimed Abandonment Victory')
	killURL(['acceptabandonvictory'])
	_send_winner(id)

@rpc('any_peer', 'call_remote', 'reliable', 0)
func start_new_game(id, pw, to):
	if playerInfo[id]['password'] != pw or (lastRequester != abs(id-1) and to):
		return
	lastRequester = -1
	killURL(['newgameaccept', 'newgamedecline'])
	if to:
		if id != -1:
			_update_chat(2, players[id] + ' Accepted New Game')
		realStartNewGame()
	else:
		_update_chat(2, players[id] + ' Declined New Game')

func _on_server_update_pressed() -> void:
	if len(moveHistory) and activeGame:
		dialog('Function no longer Usable')
		return
	var new_text = str($Body/LineEdit.text)
	if new_text == "":
		return
	hand_password(new_text)
	text = AcceptDialog.new()
	text.dialog_text = 'New Server Pass: ' + password
	text.visible = true
	surrogate.add_child(text)
	text.popup_centered()

func change_time(newStartTime, newIncrementTime):
	if len(moveHistory) and activeGame:
		return
	if not newStartTime:
		newStartTime = -1
	if newStartTime > 180:
		return
	if newStartTime < 0.25 and newStartTime != -1:
		return
	startTime = newStartTime
	if startTime > 0:
		startTime *= 60
	timeHistory = [[startTime, startTime]]
	if newIncrementTime > 180:
		return
	if newIncrementTime < 0:
		return
	incrementTime = newIncrementTime
	for t in range(2):
		$Body.get_node('Timer' + str(t)).wait_time = max(startTime, 0.001)
		$Body.get_node('Timer' + str(t)).paused = true
		if startTime != -1:
			$Body.get_node('Timer' + str(t)).start()
		_transfer_move()

func update_time(rm_last=false):
	if rm_last:
		timeHistory.remove_at(len(timeHistory)-1)
	if startTime != -1:
		timeHistory.append([$Body/Timer0.time_left, $Body/Timer1.time_left])
	else:
		timeHistory.append([startTime, startTime])

func _on_timer_0_timeout() -> void:
	update_time(true)
	if len(players):
		_update_chat(2, players[1] + ' Won on Time')
	else:
		_update_chat(2, players[0] + ' Lost on Time')
	_send_winner(1)

func _on_timer_1_timeout() -> void:
	update_time(true)
	_update_chat(2, players[0] + ' Won on Time')
	_send_winner(0)

func _on_line_edit_text_submitted(_new_text: String) -> void:
	$Body/Port.grab_focus()
	_on_server_update_pressed()

func _on_port_text_submitted(_new_text: String) -> void:
	_on_port_update_pressed()

func _on_pause_pressed() -> void:
	if len(moveHistory) and activeGame:
		dialog('Function no longer Usable')
		return
	paused = not paused
	if paused:
		$Body/Pause.text = 'Resume Server'
		_update_chat(2, 'Server Paused')
	else:
		$Body/Pause.text = 'Pause Server'
		_update_chat(2, 'Server Resumed')
	_transfer_move()

@rpc('any_peer', 'call_remote', 'reliable', 0)
func request_takeback(id, pw):
	if (playerInfo[id]['password'] != pw or paused):
		_transfer_move()
		return
	lastTakebackRequester = id
	killURL(['takebackaccept', 'takebackdecline'])
	_update_chat(2, '\n[center]' + players[id] +
		' Requested [i]Takeback[/i].\n[url=takebackaccept]Accept[/url] / [url=takebackdecline]Decline[/url][/center]\n')

func killURL(urlList):
	for m in range(len(messages)):
		for u in urlList:
			var theUrl = '[url=%s]' % [u]
			if theUrl in messages[m]:
				messages[m] = messages[m].replace(theUrl, '')
				messages[m] = messages[m].replace('[/url]', '')
	_update_chat(2, '')

func goBack(value=1):
	if value > len(moveHistory):
		return
	for i in range(value):
		clockHistory.remove_at(len(clockHistory)-1)
		captureHistory.remove_at(len(captureHistory)-1)
		history.remove_at(len(history)-1)
		moveHistory.remove_at(len(moveHistory)-1)
		if len(history) == clockActivation:
			clock = false
			clockActivation = -1
		turn = abs(turn-1)
		board = history[-1].duplicate(true)
	_transfer_move()

@rpc('any_peer', 'call_remote', 'reliable', 0)
func confirm_takeback(id, pw, to):
	if (playerInfo[id]['password'] != pw or lastTakebackRequester != abs(id-1) or paused
	or len(moveHistory) - lastTakebackRequester < 1):
		return
	killURL(['takebackaccept', 'takebackdecline'])
	if to:
		goBack({true: 2, false: 1}[turn == lastTakebackRequester])
		_transfer_move()
		if id != -1:
			_update_chat(2, players[id] + ' Accepted Takeback')
	else:
		_update_chat(2, players[id] + ' Declined Takeback')
	lastTakebackRequester = -1

@rpc('any_peer', 'call_remote', 'reliable', 0)
func imTyping(id, pw):
	if playerInfo[players.find(id)]['password'] != pw:
		return
	rpc('isTyping', id, true)

@rpc()
func isTyping(_1, _2):
	pass

func _on_port_update_pressed() -> void:
	var newServerPort = str($Body/Port.text).to_int()
	if newServerPort < 2000:
		print('Port number is too low.')
	elif newServerPort > 49000:
		print('Port number is too high.')
	dialog('Now hosting on Port ' + str(newServerPort) + ".\nDon't forget to set up Port Forwarding\n" +
		'and make Firewall rules if needed\n(both TCP and UDP required).')
	serverPort = newServerPort
	create_server()

func _on_sheref_timeout() -> void:
	var sheref_list = [
		"Server update: Sheref sucks!",
		"Wow, Sheref, you reaaally stink!",
		"Hey Sheref, can you stop playing. I'm trying to enjoy a good game.",
		"Just wait it out, Sheref, maybe your opponent will leave. That's the only way you're winning.",
		"Tip to JUST Sheref: Stop losing your drones, it's driving me insane.",
		"News Flash: You're supposed to have more points than your opponent, Sheref!",
		"Pstt... Sheref... Come here... Give up.",
		"A bit of advice from me to you, Sheref: Try OTHER games.",
		"Sheref left - Only if, then I could finally loosen up a bit.",
		"What am I even looking at, Sheref."
	]
	var rng = RandomNumberGenerator.new()
	_update_chat(2, sheref_list[rng.randi_range(0, len(sheref_list)-1)])
	sherefIt()
