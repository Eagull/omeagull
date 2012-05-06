window._gaq or = [];

track = window.track = {}

track.event = (args...) ->
	eventArr = $.merge ['_trackEvent'], args.slice(0, 3)
	window._gaq.push eventArr
