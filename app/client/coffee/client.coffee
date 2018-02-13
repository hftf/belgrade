d3 = require 'd3'
kdep = require './kde'
R = require 'ramda'

coolhead = require './coolhead'
connect = require './connect'

main = ->
	# do coolhead

	d3.json '/test/' + window.location.search.slice(1), R.compose loadData

# span = (x) -> '<span>' + x + '</span>'
# spanF = R.compose \
# 		R.join(' '),
# 		R.map(span),
# 		R.pluck('u')
# spanWord = R.curry \
# 	# r = buzzes {8: [...], 9: [...], ...}
# 	# w = word
# 	# i = index
# 	(r, w, idx) ->
# 		i = idx + 1
# 		l2 = l2c = ''
# 		if i of r
# 			# l2 = spanF r[i]
# 			l2 = r[i].length
# 			l2c = 'last'
# 		l2s = '<span class="line ' + l2c + '">' + l2 + '</span>'
# 		'<span class="word" data-index="' + i + '"><span class="line">' + w + '</span>' + l2s + '</span>'
# split = R.compose \
# 	R.join(' '),
# 	R.map(span),
# 	R.split(' ')
# splitWord = (x) -> (R.compose \
# 	R.join(' '),
# 	R.addIndex(R.map)(spanWord x),
# 	R.split(' ')
# )

# NEW
replaceMs = (p, groupedBuzzesByWord) ->
	ms = p.querySelectorAll('m')
	for m in ms
		word_index = m.getAttribute 'v'
		buzzes = groupedBuzzesByWord[word_index]
		replaceM m, buzzes
	p
replaceM = (m, buzzes) ->
	s = document.createElement 'span'
	s.setAttribute 'class', 'word'

	m.setAttribute 'class', 'line'
	word_index = m.getAttribute 'v'
	# TODO temporary. shouldn't be using id
	s.setAttribute 'data-index', word_index

	n = document.createElement 'span'
	l2 = l2c = ''
	if buzzes
		l2c = ' last'
		l2 = buzzes.length
	n.setAttribute 'class', 'line lower' + l2c
	n.innerHTML = l2

	m.parentNode.insertBefore s, m

	s.appendChild m
	s.appendChild n

splitWordM = (question, outerHTML, groupedBuzzesByWord) ->
	question.innerHTML = outerHTML
	replaceMs(question, groupedBuzzesByWord)

iconmap =
	'Fine Arts':      'paintbrush-7'
	'Literature':     'book-20'
	'History':        'time-13'
	'Social Studies': 'script-5'
	'Biology':        'virus-2'
	'Chemistry':      'flask-3'
	'Physics':        'magnet'
	'Mathematics':    'infinity'
	'Astronomy':      'rocket-11'
	'Earth Science':  'globe-4'
	'Other':          'menu-10'
iconurl = (category) ->
	'/img/iconmonstr-' + iconmap[category] + '-icon.svg'
navlink = (category) ->
	'<img class="category-image" src="' + iconurl(category) + '"> <span class="category">' + category + '</span>'

groupBuzzesByWord = R.groupBy R.prop 'p' # p means position

loadData = (err, json) ->
	groups = groupBuzzesByWord json.b

	table json.b
	x = graph json.a.p, json.a.o, json.a.category

	# document.querySelector '.category'
	# 	.innerHTML = json.a.category
	question = document.querySelector '.question'
	# question
		## .innerHTML = split json.a.raw
		# .innerHTML = splitWord(groups) json.a.raw
	splitWordM question, json.a.raw, groups
	# question.dataset.words = R.length R.split ' ', json.a.raw
	question.dataset.words = json.a.words
	lines = question.querySelectorAll '.line.last'
	rugSvgG = connect.svgGTransform document.querySelector '.rug'
	connectf = connect.connect 'rug', rugSvgG, {x}
	# R.map R.compose(connectf, R.of), lines
	# `debugger`
	# document.querySelector '.answer'
	# 	.innerHTML = json.a.answer

	# d3.select 'nav ul'
	# 	.selectAll 'li'
	# 	.data R.keys iconmap
	# 	.enter()
	# 	.append 'li'
	# 	.html navlink

table = (buzzes) ->
	x = d3.select '.buzzes'
		.selectAll 'tr'
		.data buzzes
		.enter()
		.append 'tr'
		.selectAll 'td'
		.data R.values #R.props ['']
		.enter()
		.append 'td'
		.text R.identity

		

graph = (points, categoryPoints, category) ->
	console.log points, category
	# points = json.p
	# points = [.01, 0.1, .5, 0.9, .99]
	# points = (d3.range 0, 1, .0003).map d3.scale.pow().exponent 2
	c =
		width: 640
		height: 200
		mt: 10
		mb: 60
		ml: 30
		mr: 60

	chart = d3.select '.chart'
		.attr 'width',  c.width  + c.ml + c.mr
		.attr 'height', c.height + c.mt + c.mb
		.append 'g'
		.attr 'transform', 'translate(' + c.ml + ',' + c.mt + ')'

	binwidth = 0.02
	domainp = [0, 1]
	domain = [0, 1 + binwidth]
	thresholds = d3.range 0, 1 + 2 * binwidth, binwidth

	data = (d3.layout.histogram()
		.bins thresholds
		.frequency false
		) points

	normalize = R.over R.lensProp('y'), R.flip(R.divide) binwidth
	data = R.map normalize, data

	x = d3.scale.linear()
		.range [0, c.width]
		.domain domain

	kde = kdep()
		.sample \
		# R.filter R.gt(1),
		categoryPoints
		# .kernel (x) -> 1*+(-.5<x<.5)
		# .bandwidth 0.03
		.bounds domainp
	kdes = kde \
		#R.map R.pipe(
		# kde.bandwidth,
		#R.flip(R.call) \
		R.append 1, d3.range domainp..., 3 / c.width
		# ),
		# R.concat [binwidth, .1], 
		# d3.values science.stats.bandwidth
		console.log do kde.bandwidth

	y = d3.scale.linear()
		.range [c.height, 0]
		.domain [0, d3.max [
			d3.max data, R.prop 'y'
			d3.max R.flip(R.map) kdes, R.flip(d3.max) R.prop '1'
		]]
		.nice 4

	bar = chart.selectAll 'g'
		.data data
		.enter()
		.append 'g'
		.attr 'class', 'bar'
		.attr 'transform', (d) -> 'translate(' + x(d.x) + ',' + y(d.y) + ')'

	bar.append 'rect'
		.attr 'x', 1
		.attr 'width', x(data[0].dx) - 1
		.attr 'height', (d) -> c.height - y(d.y)

	# kde

	line = d3.svg.line()
		.interpolate 'basis'
		.x (d) -> x d[0]
		.y (d) -> y d[1]

	chart.append 'path'
		.attr 'class', 'kde'
		.attr 'd', line kdes

	# labels

	ftp = 0.84

	xaxis = d3.svg.axis()
		.scale x
		# .tickValues [.5, .84, 1]
		# .tickFormat (x) -> if x is ftp then 'FTP' else d3.format('0%') x
		.ticks 4
		.outerTickSize 0
		.orient 'bottom'

	yaxis = d3.svg.axis()
		.scale y
		.ticks 4
		# .tickFormat ''
		.orient 'right'

	chart.append 'text'
		.text 'dotted line = pdf(All ' + category + ' tossups)'
		.attr 'transform', 'translate(20, 20)'

	# commented?
	chart.append 'g'
		.attr 'class', 'y axis'
		.attr 'transform', 'translate(' + (c.width + 12) + ',0)'
		.call yaxis
		.append 'text'
		.attr 'class', 'label'
		.text 'Buzzes'
		.attr 'text-anchor', 'middle'
		.attr 'transform', 'translate(' + 40 + ',' + (c.height/2) + ') rotate(-90)'

	chart.append 'g'
		.attr 'class', 'x axis'
		.attr 'transform', 'translate(0,' + c.height + ')'
		.call xaxis
		.append 'text'
		.attr 'class', 'label'
		.text 'Position in tossup (%)'
		.attr 'transform', 'translate(' + c.width/2 + ',50)'

	x # hack return

do main
