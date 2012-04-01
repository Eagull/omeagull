_gaq = window._gaq or = [];
_gaq.push(['_setAccount', 'UA-21159963-5']);
_gaq.push(['_trackPageview']);

track = window.track = {}

track.event = (category, action, label) ->
	args = ['_trackEvent', category]
	args.push action if action
	args.push label if label
	_gaq.push args
