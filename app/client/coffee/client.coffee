d3 = require 'd3'
kdep = require './kde'
R = require 'ramda'

coolhead = require './coolhead'
connect = require './connect'

tossup_id = window.location.search.slice(1)

main = ->
	d3.json '/test/' + tossup_id, R.compose loadData

# NEW
tick_delta = 0.1
replaceMs = (p, groupedBuzzesByWord, words) ->
	ms = p.querySelectorAll('m')
	last_word_index = null
	next_tick = tick_delta
	for m in ms
		word_index = m.getAttribute 'v'
		if word_index == last_word_index
			continue
		last_word_index = word_index
		buzzes = groupedBuzzesByWord[word_index]

		if (word_index / words) > next_tick and word_index < words
			s = document.createElement 'span'
			s.setAttribute 'class', 'next_tick'
			s.innerHTML = '<b>' + next_tick.toFixed(1) + '</b> ' + word_index
			m.style.position = 'relative'
			# m.parentNode.insertBefore s, m
			m.appendChild s
			next_tick += tick_delta

		replaceM m, buzzes
	p
replaceM = (m, buzzes) ->
	diffStat = buzzesToDiffStat(buzzes)

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
		l2 = diffStat
	n.setAttribute 'class', 'line lower' + l2c
	n.innerHTML = l2

	m.parentNode.insertBefore s, m

	s.appendChild m
	s.appendChild n

classifyBuzz = (buzz) ->
	if buzz.buzz_value <= 0
		'neg'
	else if buzz.bounceback != null # == 'bounceback'
		'bb' #bounceback-get
	else
		'get'
groupBuzzesAtLocationByCorrect = R.groupBy classifyBuzz
buzzesToDiffStat = (buzzes) ->
	if not buzzes?
		return ''

	groupedBuzzesAtLocation = groupBuzzesAtLocationByCorrect buzzes
	lengths = R.mapObjIndexed R.length, groupedBuzzesAtLocation
	diffStat = []
	if 'get' of lengths
		diffStat.push '<span class="get">' + lengths['get'] + '</span>'
	if 'bb' of lengths
		diffStat.push '<span class="bb">+' + lengths['bb'] + '</span>'
	if 'neg' of lengths
		diffStat.push '<span class="neg">–' + lengths['neg'] + '</span>'
	diffStat.join ' '

splitWordM = (question, a, groupedBuzzesByWord) ->
	outerHTML = a.raw[0]
	question.innerHTML = outerHTML
	replaceMs(question, groupedBuzzesByWord, a.words)

groupBuzzesByWord = R.groupBy R.prop 'p' # p means position

loadData = (err, json) ->
	groups = groupBuzzesByWord json.b

	table json.b
	x = graph json.a.p, json.a.o, json.a.category

	question = document.querySelector '.question'
	document.querySelector('.edition').innerHTML = json.a.question_set_edition_date
	document.querySelector('.packet').innerHTML = json.a.packet_name
	document.querySelector('.answer').innerHTML = json.a.raw[1]
	document.querySelector('.prev').href = '?' + (+tossup_id - 1)
	document.querySelector('.next').href = '?' + (+tossup_id + 1)
	splitWordM question, json.a, groups
	question.dataset.words = json.a.words
	lines = question.querySelectorAll '.line.last'
	# rugSvgG = connect.svgGTransform document.querySelector '.rug'
	# connectf = connect.connect 'rug', rugSvgG, {x}
	# R.map R.compose(connectf, R.of), lines

table = (buzzes) ->
	x = d3.select '.buzzes'
		.selectAll 'tr'
		.data buzzes
		.enter()
		.append 'tr'
		.attr('class', (d) -> classifyBuzz(d))
		.on 'mouseover', (d, i) -> document.querySelector('[data-index="' + d.p + '"]').classList.add    'hover'
		.on 'mouseout',  (d, i) -> document.querySelector('[data-index="' + d.p + '"]').classList.remove 'hover'
		.selectAll 'td'
		.data R.values #R.props ['']
		.enter()
		.append 'td'
		.text R.identity

		

graph = (points, categoryPoints, category) ->
	# points = json.p
	# points = [.01, 0.1, .5, 0.9, .99]
	# points = (d3.range 0, 1, .003).map d3.scale.pow().exponent 2
	c =
		width: 640
		height: 220
		mt: 45
		mb: 60
		ml: 30
		mr: 80

	chart = d3.select '.chart'
		.attr 'width',  c.width  + c.ml + c.mr
		.attr 'height', c.height + c.mt + c.mb
		.append 'g'
		.attr 'transform', 'translate(' + c.ml + ',' + c.mt + ')'

	binwidth = 0.025
	domainp = [0, 1]
	domain = [0, 1 + binwidth]
	thresholds = d3.range 0, 1 + 2 * binwidth, binwidth

	data = (d3.layout.histogram()
		.bins thresholds
		.frequency true
		) points

	normalize = R.over R.lensProp('y'), R.flip(R.divide) binwidth
	# only use if frequency = true
	# data = R.map normalize, data

	# last = 0
	# for i in data
	# 	i.y = last + i.y
	# 	last = i.y

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
		.domain [0, 1 + d3.max [
			d3.max data, R.prop 'y'
			d3.max R.flip(R.map) kdes, R.flip(d3.max) R.prop '1'
		]]
		# .domain [0, 30]
		.nice 4

	bar = chart.selectAll 'g'
		.data data
		.enter()
		.append 'g'
		.attr 'class', 'bar'
		.attr 'transform', (d) -> 'translate(' + x(d.x) + ',' + y(d.y) + ')'

	bar.append 'rect'
		.attr 'x', 0
		.attr 'width', x(data[0].dx)
		.attr 'height', (d) -> c.height - y(d.y)

	# kde

	line = d3.svg.line()
		.interpolate 'basis'
		.x (d) -> x d[0]
		.y (d) -> y d[1]

	chart.append 'path'
		.attr 'class', 'kde'
		.attr 'd', line kdes

	# legend
	chart.append 'path'
		.attr 'class', 'kde'
		.attr 'd', "M 10,14 L 40,14"
	chart.append 'g'
		.attr 'class', 'bar'
		.append 'rect'
		.attr 'x', '10'
		.attr 'y', '30'
		.attr 'width', '30'
		.attr 'height', '12'

	# labels

	ftp = 0.84

	xaxis = d3.svg.axis()
		.scale x
		# .tickValues [.5, .84, 1]
		# .tickFormat (x) -> if x is ftp then 'FTP' else d3.format('0%') x
		.ticks 4
		.tickSize -c.height
		.outerTickSize 0
		.orient 'bottom'

	yaxis = d3.svg.axis()
		.scale y
		.ticks 5
		.tickSize -c.width
		.outerTickSize 0
		# .tickFormat ''
		.orient 'right'
	chart.append 'text'
		.text 'pdf(All ' + category + ' tossups)'
		.attr 'transform', 'translate(50, 20)'
	chart.append 'text'
		.text 'All correct buzzes'
		.attr 'transform', 'translate(50, 42)'

	# commented?
	chart.append 'g'
		.attr 'class', 'y axis'
		.attr 'transform', 'translate(' + (c.width) + ',0)'
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
		.text 'Position in tossup'
		.attr 'transform', 'translate(' + c.width/2 + ',40)'


	box = [
		d3.quantile(points, 0.2),
		d3.quantile(points, 0.4),
		d3.quantile(points, 0.5),
		d3.quantile(points, 0.6),
		d3.quantile(points, 0.8)
	]

	chart.append("path")
		.attr("d", 'M0,' + c.height + ' L0,0 H' + x(box[0]) + ' V-4 H' + x(box[1]) + ' V-8 H' + x(box[2]) + ' V0 V-8 H' + x(box[3]) + ' V-4 H' + x(box[4]) + ' V0 H' + c.width)
		.attr("fill", "none")
		.attr("stroke", "black")
	topaxisg = chart.append("g")
		.attr("font-size","10")
	txt = topaxisg.append("text")
		.attr("transform", 'translate(' + ( 3 + x(box[0]) ) + ',-6) rotate(-90)')
		.attr("text-anchor","start")		
	txt.append("tspan").text("20% of").attr("x","0").attr("dy","0")
	txt.append("tspan").text("buzzes").attr("x","0").attr("dy","8")
	if (x(box[1]) - x(box[0]) > 16)
		topaxisg.append("text")
			.text("40%")
			.attr("transform", 'translate(' + ( 3 + x(box[1]) ) + ',-10) rotate(-90)')
			.attr("text-anchor","start")
	if (x(box[2]) - x(box[1]) > 8)
		topaxisg.append("text")
			.text("Median")
			.attr("transform", 'translate(' + ( 3 + x(box[2]) ) + ',-10) rotate(-90)')
			.attr("text-anchor","start")
	if (x(box[3]) - x(box[2]) > 8)
		topaxisg.append("text")
			.text("60%")
			.attr("transform", 'translate(' + ( 3 + x(box[3]) ) + ',-10) rotate(-90)')
			.attr("text-anchor","start")
	if (x(box[4]) - x(box[3]) > 8)
		topaxisg.append("text")
			.text("80%")
			.attr("transform", 'translate(' + ( 3 + x(box[4]) ) + ',-6) rotate(-90)')
			.attr("text-anchor","start")

	x # hack return

do main
