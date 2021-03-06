blaze = window.blaze or = {}
config = blaze.config or = {}

Array.prototype.random = () -> @[Math.floor((Math.random()*@length))];

blaze.util =
	randomInt: (a, b) ->
		b or= 0
		max = if a > b then a else b
		min = if a > b then b else a
		Math.floor (Math.random() * (max-min) + min)

	normalizeStr: (str) -> str.trim().replace(/\s{2,}/g, ' ').replace(/\./g, '').toLowerCase()

	linkify: (text) ->
		pattern = /(\b(https?):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/gim
		text.replace pattern, '<a href="$1">$1</a>'

blaze.view =
	notification: (opts) ->
		return if not webkitNotifications or webkitNotifications.checkPermission() isnt 0 or document.hasFocus()
		notification = webkitNotifications.createNotification "/logo16.png", opts.title or "", opts.body or ""
		notification.onclick = -> window.focus(); @cancel()
		notification.show()
		setTimeout (-> notification.cancel()), opts.timeout or 15000, notification

	lightbox: (content, opts) ->
		$.extend opts,
			closeBtn: false
			helpers:
				overlay:
					css:
						position: 'fixed'
						top: '0px'
						right: '0px'
						bottom: '0px'
						left: '0px'
		$.fancybox content, opts
