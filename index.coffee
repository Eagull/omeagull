view = blaze.view or {}
util = blaze.util
config = blaze.config or {}
messages = blaze.messages

NICK_LIST = ["Abra", "Charmander", "Jigglypuff", "Metapod", "Pikachu", "Psyduck", "Squirtle"]

$.getJSON('nick.json').success (list) ->
	NICK_LIST = list

config.ROOM = if blaze.debug then 'test@chat.eagull.net' else 'firemoth@chat.eagull.net'
config.STATUS_START = "You're now chatting with FireMoth's Stranger Abducter."
config.SCREEN_RESPONSE_EXPECTED = "I agree"

getRandomNick = -> NICK_LIST[util.randomInt(NICK_LIST.length)]

view.updateXMPPStatus = (d) ->
	$('#xmppStatus').text d

view.clearConsole = ->
	$('.logbox').html ''

view.append = (e) ->
	$('.logbox').append $('<div>').attr('class', 'logitem').append e

view.log = (template, msg, nick) ->
	msg = $('<div>').text(msg).html()
	msg = util.linkify msg
	$('.logbox').append $(template).text().replace('{nick}', nick).replace('{msg}', msg)
	$('.logbox').scrollTop $('.logbox').prop('scrollHeight')

view.youMsg = (msg, nick) ->
	view.log '#templateYouMsg', msg, nick or 'Me'

view.strangerMsg = (msg, nick) ->
	view.log '#templateStrangerMsg', msg, nick or 'Stranger'

view.privateMsg = (msg, from, to) ->
	view.log '#templatePrivateMsg', msg, "#{from} -> #{to}"

view.statusMsg = (msg) ->
	view.log '#templateStatusMsg', msg

view.image = (src, alt) ->
	alt or = ''
	img = $('<img>').attr('src', src).attr('alt', alt).attr('title', alt)
	$('.logbox').append $('<div>').append img
	img.on 'load', -> $('.logbox').scrollTop $('.logbox').prop('scrollHeight')

sendMessage = (msg) ->
	msg = $.trim msg
	return if not msg

	if msg[0] is '/'
		args = msg.substr(1).split(' ')
		command = args.shift()
		if commands[command]
			track.event 'command', command, args.join ' '
			return if commands[command].call(undefined, args)

	if msg[0] is '@'
		nick = msg.substr(1).split(' ', 1)[0]
		message = msg.substr(msg.indexOf(' ')).trim()
		if config.joinedRoom
			if xmpp.rooms[config.joinedRoom].roster.indexOf(nick) isnt -1
				xmpp.send config.joinedRoom + '/' + nick, message, type: 'chat'
				view.privateMsg message, config.nick, nick
				track.event 'message', 'chat', 'out'
				return

	if config.joinedRoom
		xmpp.conn.muc.groupchat config.joinedRoom, msg
	else
		view.youMsg msg
		if util.normalizeStr(msg) is util.normalizeStr(config.SCREEN_RESPONSE_EXPECTED)
			config.challengePassed = true
			config.nick = getRandomNick()
			xmpp.join config.ROOM, config.nick
			view.strangerMsg messages.challengeAccept.random()
			track.event 'challenge', 'accept', msg
		else
			view.strangerMsg messages.challengeReject.random()
			track.event 'challenge', 'reject', msg

commands =
	help: ->
		commandList = []
		$.each commands, (i) ->
			commandList.push "/#{i}"
		view.statusMsg "Commands: " + commandList.join(', ')
		true

	pm: ->
		view.statusMsg "To PM someone, type @ followed by their nickname, then a space, then the message. Good luck!"
		true

	nick: (args) ->
		newNick = args.shift()
		if not config.joinedRoom
			view.statusMsg messages.actionImpossible.random()
			return true
		if not newNick
			view.statusMsg messages.invalidInput.random()
			return false
		if not /^[a-zA-Z](\w)*$/.test(newNick)
			view.statusMsg messages.invalidInput.random()
			return false
		if newNick.length > 20
			view.statusMsg messages.invalidInput.random()
			return false
		if util.randomInt(10) < 6
			xmpp.conn.muc.changeNick config.joinedRoom, newNick
		else
			 xmpp.conn.muc.changeNick config.joinedRoom, getRandomNick()
		true

	users: ->
		if util.randomInt(10) < 2
			view.statusMsg "Why should I tell you? ;)"
		else if not config.joinedRoom
			view.statusMsg "What users?"
		else
			view.statusMsg "Users: " + xmpp.rooms[config.joinedRoom].roster.join(', ')
		true

	history: ->
		if not config.history
			view.statusMsg "I have nothing for you."
			return true
		while config.history.length > 0
			msg = config.history.shift()
			view.strangerMsg msg.text, msg.nick
		true

	xkcd: (args) ->
		num = args.shift()
		num = if num and not isNaN(num) then num else ''
		if config.xkcdlatest and num and num > config.xkcdlatest
			view.statusMsg "I have nothing for you."
			return false
		url = 'http://dynamic.xkcd.com/api-0/jsonp/comic/' + num
		$.ajax
			url: url
			cache: true
			success: (data) ->
				view.statusMsg "(#{data.num}) #{data.title}"
				view.image(data.img, data.alt)
				if not num
					config.xkcdlatest = data.num
			error: -> view.statusMsg "You can't have it. ;)"
			dataType: 'jsonp'
			jsonpCallback: -> "cb" + Date.now()
		true

$ ->
	$("input.persistent, textarea.persistent").each (index, element) ->
		value = localStorage.getItem 'field-' + (element.name || element.id)
		element.value = value if value

	$("input.persistent, textarea.persistent").change (event) ->
		element = event.target
		if not element.validity.valid
			localStorage.setItem 'field-' + (element.name || element.id), ""
		else
			localStorage.setItem 'field-' + (element.name || element.id), element.value

	$('.disconnectbtn').click ->
		if not config.joinedRoom or not config.challengePassed
			view.statusMsg messages.actionImpossible.random()
			return
		msg = $('<div>').text messages.disconnectRequest.random()
		txtNick = $('<input>').val config.nick
		msg.append $('<div>').css('text-align', 'center').css('margin-top', '1rem').append txtNick
		txtNick.change ->
			newnick = txtNick.val()
			return if not newnick
			xmpp.conn.muc.changeNick config.joinedRoom, newnick
		txtNick.keypress (e) -> if e.which is 13 then $.fancybox.close()
		view.lightbox msg,
			afterShow: -> txtNick.focus()

	$('.sendbtn').click ->
		msg = $.trim $('.chatmsg').val()
		$('.chatmsg').val ''
		if msg
			sendMessage msg
		else
			view.statusMsg messages.actionImpossible.random()

	$('.chatmsg').keydown (e) ->
		if e.which is 9
			e.preventDefault()
			view.statusMsg messages.resultUnavailable.random()
		if e.which is 13
			e.preventDefault()
			sendMessage e.target.value
			e.target.value = ""

	$('a.ajax').click (e) ->
		e.preventDefault()
		a = e.target
		doc = a.getAttribute('x-doc')
		url = if doc then "http://content.dragonsblaze.com/json/#{doc}" else a.href
		$.ajax
			url: url
			success: (data) -> view.lightbox data.content
			dataType: 'jsonp'
			jsonpCallback: -> "cb" + Date.now()

	$(document).click 'a', (e) ->
		e.target.target = '_blank'

	window.onbeforeunload = ->
		xmpp.conn.disconnect()
		return

	xmpp.connect $('#txtXmppId').val(), $('#txtXmppPasswd').val()

	$('.chatmsg').focus()

	fb = (d, s, id) ->
		fjs = d.getElementsByTagName(s)[0]
		return if (d.getElementById(id))
		js = d.createElement(s)
		js.id = id
		js.src = "//connect.facebook.net/en_US/all.js#xfbml=1&appId=216540884750";
		fjs.parentNode.insertBefore(js, fjs);
	fb(document, 'script', 'facebook-jssdk')

$(xmpp).bind 'connecting error authenticating authfail connected connfail disconnecting disconnected', (event) ->
	view.updateXMPPStatus event.type
	track.event 'XMPP', event.type

$(xmpp).bind 'error authfail connfail disconnected', (event) ->
	view.statusMsg "Connection Status: " + event.type
	view.append $('<button>').text("Reconnect").click ->
		view.clearConsole()
		xmpp.connect $('#txtXmppId').val(), $('#txtXmppPasswd').val()

$(xmpp).bind 'connecting disconnecting', (event) ->
	view.statusMsg event.type + "..."

$(xmpp).bind 'connected', (event) ->
	view.clearConsole()
	view.statusMsg config.STATUS_START
	view.strangerMsg "** " + messages.welcome.random()
	if webkitNotifications and webkitNotifications.checkPermission() is 1
		view.append $('<button>').text("Enable Notifications").click (e) ->
			webkitNotifications.requestPermission this
			$(e.target).remove()

$(xmpp).bind 'groupMessage', (event, data) ->
	msg = $.trim(data.text)
	return if not msg
	config.history or = []
	config.history.push data
	config.history.shift() if config.history.length > 10
	if data.delay
		return
	else if data.nick is config.nick
		view.youMsg msg, data.nick
		track.event 'message', 'groupchat', 'out'
	else
		view.strangerMsg msg, data.nick
		if msg.toLowerCase().indexOf(config.nick.toLowerCase()) isnt -1
			view.notification
				title: data.nick
				body: msg
		track.event 'message', 'groupchat', 'in'

$(xmpp).bind 'privateMessage', (event, data) ->
	msg = $.trim(data.text)
	return if not msg
	view.privateMsg msg, data.nick, config.nick
	view.notification
		title: data.nick
		body: msg
	track.event 'message', 'chat', 'in'

$(xmpp).bind 'joined', (event, data) ->
	if data.nick is config.nick
		config.joinedRoom = data.room
	else
		view.statusMsg messages.joined.random().replace '{nick}', data.nick

$(xmpp).bind 'parted', (event, data) ->
	return if config.joinedRoom isnt data.room
	if data.nick is config.nick
		delete config.joinedRoom
	else
		view.statusMsg messages.parted.random().replace '{nick}', data.nick

$(xmpp).bind 'kicked', (event, data) ->
	if data.nick is config.nick
		delete config.joinedRoom
		msg = messages.meKicked.random()
		msg += " (reason: #{data.reason})" if data.reason
		view.statusMsg msg
	else
		msg = messages.userKicked.random().replace '{nick}', data.nick
		msg += " (reason: #{data.reason})" if data.reason
		view.statusMsg msg

$(xmpp).bind 'nickChange', (event, data) ->
	if data.nick is config.nick
		config.nick = data.newNick
		view.statusMsg messages.meNickChanged.random().replace '{nick}', data.newNick
	else
		view.statusMsg messages.userNickChanged.random().replace('{nick}', data.nick).replace '{newNick}', data.newNick
