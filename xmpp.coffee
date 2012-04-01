xmpp = window.xmpp = window.xmpp || {}

DEFAULT_BOSH_SERVICE = 'http://xmpp.eagull.net:5280/http-bind'
DEFAULT_USER = 'anon.eagull.net'
RESOURCE = "omeagull-#{eagull.version}-#{parseInt(Date.now()/1000)}"
xmpp.debug = xmpp.debug is true

xmpp.rooms = {}

xmpp.send = (to, msg, attr) ->
	attr = attr or {}
	attr.to = to
	attr.type = attr.type or 'groupchat'
	xmpp.conn.send($msg(attr).c('body', null, msg))

xmpp.join = (room, nick) ->
	xmpp.conn.send $pres({from: xmpp.conn.jid, to: room + '/' + nick}).c('x', {xmlns: Strophe.NS.MUC })
	xmpp.rooms[room] =
		nick: nick
		roster: []

xmpp.part = (room, msg) ->
	p = $pres
		to: room
		type: 'unavailable'
	p.c('x', {xmlns: Strophe.NS.MUC }).up()
	p.c('status', null, msg) if msg
	xmpp.conn.send p

xmpp.eventMessageHandler = (msg) ->
	bodyTags = msg.getElementsByTagName 'body'
	return true if bodyTags.length == 0

	delay = if msg.getElementsByTagName('delay').length then true else false

	type = msg.getAttribute 'type'
	if type is 'chat'
		$(xmpp).triggerHandler 'privateMessage',
			to: msg.getAttribute 'to'
			nick: Strophe.getResourceFromJid(msg.getAttribute 'from')
			text: $('<div>').html(Strophe.getText(bodyTags[0])).text()
		return true

	$(xmpp).triggerHandler 'groupMessage',
		to: msg.getAttribute 'to'
		nick: Strophe.getResourceFromJid(msg.getAttribute 'from')
		text: $('<div>').html(Strophe.getText(bodyTags[0])).text()
		delay: delay

	true

xmpp.mucPresenceHandler = (p) ->

	room = Strophe.getBareJidFromJid p.getAttribute 'from'
	nick = Strophe.getResourceFromJid p.getAttribute 'from'

	return true if room not of xmpp.rooms

	statusElems = p.getElementsByTagName('status')
	statusCodes = (parseInt(s.getAttribute('code')) for s in statusElems)

	if statusCodes.indexOf(110) >= 0 and p.getAttribute('type') isnt 'unavailable'
		xmpp.rooms[room].joined = true
	else if not xmpp.rooms[room].joined
		xmpp.rooms[room].roster.push nick
		return true

	if p.getAttribute('type') is 'unavailable'
		i = xmpp.rooms[room].roster.indexOf nick
		xmpp.rooms[room].roster.splice(i, 1) if i isnt -1

		if xmpp.rooms[room].nick is nick and statusCodes.indexOf(303) < 0
			delete xmpp.rooms[room]

		if statusCodes.indexOf(307) >= 0
			reasonElems = p.getElementsByTagName('reason')
			if reasonElems.length > 0
				reason = Strophe.getText(reasonElems[0])
			$(xmpp).triggerHandler 'kicked',
				room: room
				nick: nick
				reason: reason or ""

		else if statusCodes.indexOf(303) >= 0
			itemElem = p.getElementsByTagName('item')[0]
			newNick = itemElem.getAttribute('nick')
			xmpp.rooms[room].roster.push newNick
			$(xmpp).triggerHandler 'nickChange',
				room: room
				nick: nick
				newNick: newNick

		else
			status = Strophe.getText(statusElems[0]) if statusElems.length > 0
			$(xmpp).triggerHandler 'parted',
				room: room
				nick: nick
				status: status or ""

	else if xmpp.rooms[room].roster.indexOf(nick) is -1
		xmpp.rooms[room].roster.push nick
		$(xmpp).triggerHandler 'joined',
			room: room
			nick: nick

	true

onConnect = (status) ->
	switch status
		when Strophe.Status.ERROR
			$(xmpp).triggerHandler 'error'
			console.error 'Strophe encountered an error.'

		when Strophe.Status.CONNECTING
			$(xmpp).triggerHandler 'connecting'
			console.log 'Strophe is connecting.'

		when Strophe.Status.CONNFAIL
			$(xmpp).triggerHandler 'connfail'
			console.error 'Strophe failed to connect.'

		when Strophe.Status.AUTHENTICATING
			$(xmpp).triggerHandler 'authenticating'
			console.log 'Strophe is authenticating.'

		when Strophe.Status.AUTHFAIL
			$(xmpp).triggerHandler 'authfail'
			console.error 'Strophe failed to authenticate.'

		when Strophe.Status.CONNECTED
			$(xmpp).triggerHandler 'connected'
			console.log 'Strophe is connected.'
			xmpp.conn.addHandler xmpp.eventMessageHandler, null, 'message'
			xmpp.conn.addHandler xmpp.mucPresenceHandler, null, 'presence'
			xmpp.conn.send $pres().tree()

		when Strophe.Status.DISCONNECTED
			$(xmpp).triggerHandler 'disconnected'
			console.log 'Strophe is disconnected.'

		when Strophe.Status.DISCONNECTING
			$(xmpp).triggerHandler 'disconnecting'
			console.log 'Strophe is disconnecting.'

		when Strophe.Status.ATTACHED
			$(xmpp).triggerHandler 'attached'
			console.log 'Strophe attached the connection.'

	true

xmpp.connect = (id, passwd, service) ->
	if xmpp.conn and (xmpp.conn.connecting or xmpp.conn.connected)
		xmpp.conn.disconnect()

	service or = DEFAULT_BOSH_SERVICE
	xmpp.conn = new Strophe.Connection service

	id or= DEFAULT_USER
	id = Strophe.getBareJidFromJid(id) + '/' + RESOURCE
	passwd or= ''
	xmpp.conn.connect id, passwd, onConnect

	if xmpp.debug
		xmpp.conn.rawInput = (data) ->
			console.debug "RECV: " + data
		xmpp.conn.rawOutput = (data) ->
			console.debug "SENT: " + data
