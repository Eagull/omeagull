_gaq = window._gaq or = [];
_gaq.push(['_setAccount', 'UA-21159963-5']);
_gaq.push(['_trackPageview']);

track = window.track = {}

track.event = (args...) ->
	args.unshift '_trackEvent'
	_gaq.push args
