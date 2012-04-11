from google.appengine.api.urlfetch import fetch
import re
import webapp2

class ChallengeRequestHandler(webapp2.RequestHandler):
	def get(self, key):
		if not key:
			self.error(404)
			self.response.out.write('404 Not Found: %s' % key)
			return

		result = fetch("http://www.google.com/recaptcha/api/challenge?k=%s" % key, deadline=10)
		challenge = re.search("challenge : '(.+?)'", result.content).group(1)

		cb = self.request.get('callback')
		if cb:
			self.response.headers['Content-Type'] = 'text/javascript'
			self.response.out.write('%s && %s("%s")' % (cb, cb, challenge))
		else:
			self.response.headers['Content-Type'] = 'application/json'
			self.response.out.write(challenge)

class ImageRequestHandler(webapp2.RequestHandler):
	def get(self, challenge):
		if not challenge:
			self.error(404)
			self.response.out.write('404 Not Found: %s' % challenge)
			return

		self.response.headers['Content-Type'] = 'image/jpeg'
		self.response.out.write(fetch("http://www.google.com/recaptcha/api/image?c=%s" % challenge, deadline=10).content)

app = webapp2.WSGIApplication([
	('/captchaChallenge/(.*)', ChallengeRequestHandler),
	('/captchaImage/(.*)', ImageRequestHandler),
	], debug=False)
