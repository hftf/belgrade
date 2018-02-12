R = require 'ramda'
connect = require './connect'

differ = (s1, s2) ->
	for i in [0...s1.length] by 1
		break if s1[i] isnt s2[i]
	i

fragBuilder = do ->
	textn = (x) -> document.createTextNode x
	spann = (str) -> document.createElement 'span'

	(el) ->
		frag = do document.createDocumentFragment
		text = (str) ->
			frag.appendChild textn str
		append = (str) ->
			frag.appendChild do spann
				.appendChild textn str
				.parentNode
		spacepend = (str) ->
			if do frag.hasChildNodes
				frag.appendChild textn ' '
			append str
		final = -> el.replaceChild frag, el.firstChild

		{text, append, spacepend, final}

coolhead = ->
	header = document.querySelector 'header'

	els = R.map header.querySelector.bind(header), ['h1.acronym', 'p.words']
	[acronym, phrase] = R.pluck 'textContent', els
	words = phrase.split ' '

	[h1frag, pfrag] = frags = R.map fragBuilder, els

	spanpairs = for w in words
		spans = [
			h1frag.append m = acronym.slice 0, d = differ acronym, w
			pfrag.spacepend m
		]
		# only above 2 get passed to connect
		pfrag.text w.slice d
		acronym = acronym.slice d
		spans

	R.map R.call, R.pluck 'final', frags

	# R.map R.apply(connect), spanpairs

	svg = document.querySelector 'svg.coolhead'
	connectf = connect.connect 'tuningFork', svg, {}
	R.map connectf, spanpairs

module.exports = coolhead
