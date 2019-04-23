d3 = require 'd3'
kdep = require './kde'
R = require 'ramda'
clipboard = require 'clipboard-polyfill'


# NEW
tick_delta = 0.1
# formatBzPct = (next_tick) -> (next_tick*100).toFixed(0) + '%'
formatBzPct = (next_tick) -> (next_tick*1).toFixed(2)
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
			s.innerHTML = '<b>' + formatBzPct(next_tick) + '</b> ' + word_index
			m.style.position = 'relative'
			# m.parentNode.insertBefore s, m
			m.appendChild s
			next_tick += tick_delta

		replaceM m, buzzes
	p
replaceM = (m, buzzes) ->
	diffStat = buzzesToDiffStat(buzzes)

	s = document.createElement 'span'

	m.setAttribute 'class', 'line'
	word_index = m.getAttribute 'v'
	# TODO temporary. shouldn't be using id
	s.setAttribute 'data-index', word_index

	n = document.createElement 'span'
	sc = l2 = l2c = ''
	if buzzes
		sc = ' has_buzzes'
		l2c = ' last'
		l2 = diffStat
	n.setAttribute 'class', 'line lower' + l2c
	n.innerHTML = l2

	m.parentNode.insertBefore s, m

	s.setAttribute 'class', 'word' + sc
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
		diffStat.push '<span class="neg">−' + lengths['neg'] + '</span>'
	diffStat.join ' '

splitWordM = (question, groupedBuzzesByWord) ->
	replaceMs(question, groupedBuzzesByWord, +question.dataset.words)

groupBuzzesByWord = R.groupBy R.prop 'p' # p means position

window.loadData = () ->
	graph window.tossup.a, window.allCategoryKdes.d, window.allCategoryKdes.kdeXs

	groups = groupBuzzesByWord window.tossup.b
	question = document.querySelector '.question'
	splitWordM question, groups

	do setRowHandlers

onHover = (base, method) -> (e) ->
	p = this.dataset.index
	document.querySelectorAll('[data-index="' + p + '"]').forEach (el) -> el.classList[method] 'hover'
setRowHandlers = () ->
	question = document.querySelector '.question'
	buzzes = document.querySelector '.buzzes'
	rHA = onHover question, 'add'
	rHR = onHover question, 'remove'
	wHA = onHover buzzes, 'add'
	wHR = onHover buzzes, 'remove'
	document.querySelectorAll('.buzzes tr').forEach (el) ->
		el.onmouseover = rHA
		el.onmouseout  = rHR
	document.querySelectorAll('.question .word.has_buzzes').forEach (el) ->
		el.onmouseover = wHA
		el.onmouseout  = wHR

graph = (a, allCategoryKdes, kdeXs) ->
	# points = [.01, 0.1, .5, 0.9, .99]
	# points = (d3.range 0, 1, .003).map d3.scale.pow().exponent 2
	gets = a.p
	negs = a.n

	c =
		width: 41*16
		height: 220
		mt: 45
		mb: 60
		mz: 10
		ml: 20
		mr: 80

	chart = d3.select '.chart'
		.attr 'width',  c.width  + c.ml + c.mr
		.attr 'height', 2 * c.height + c.mt + c.mb + c.mz
		.append 'g'
		.attr 'transform', 'translate(' + c.ml + ',' + c.mt + ')'

	binwidth = 0.025
	domainp = [0, 1]
	domain = [0, 1 + binwidth]
	thresholds =	
		d3.range 0, 1 + binwidth, binwidth
			.map (v) -> parseFloat v.toFixed 4

	# remove null buzz points
	gets = gets.filter (x) -> !!x
	negs = negs.filter (x) -> !!x
	
	histogramF = d3.histogram()
		.domain domain
		.thresholds thresholds
	gets_data = histogramF gets
	negs_data = histogramF negs

	# normalize = R.over R.lensProp('length'), R.flip(R.divide) gets_data.length
	# gets_data = R.map normalize, gets_data

	# last = 0
	# for i in gets_data
	# 	i.length = last + i.length
	# 	last = i.length

	x = d3.scaleLinear()
		.range [0, c.width]
		.domain domain

	barWidth = x(gets_data[0].x1 - gets_data[0].x0)
	yMax = 1 + d3.max [
			d3.max gets_data, R.prop 'length'
			d3.max negs_data, R.prop 'length'
			2 # d3.max R.flip(R.map) kdes, R.prop '1'
		]
	y = d3.scaleLinear()
		.range [c.height, 0]
		.domain [0, yMax]
		# .domain [0, 30]
		.nice 4
	negs_y = d3.scaleLinear()
		.range [c.height + c.mb, 2 * c.height + c.mb]
		.domain [0, yMax]
		# .domain [0, 30]
		.nice 4

	gets_bar = chart.append 'g'
		.selectAll 'g'
		.data gets_data
		.enter()
		.append 'g'
		.attr 'class', 'bar'
		.attr 'transform', (d) -> 'translate(' + x(d.x0) + ',' + y(d.length) + ')'
	gets_bar.append 'rect'
		.attr 'x', 0
		.attr 'width', barWidth
		.attr 'height', (d) -> c.height - y(d.length)

	negs_bar = chart.append 'g'
		.selectAll 'g'
		.data negs_data
		.enter()
		.append 'g'
		.attr 'class', 'bar neg'
		.attr 'transform', (d) -> 'translate(' + x(d.x0) + ',' + (c.height + c.mb) + ')'
	negs_bar.append 'rect'
		.attr 'x', 0
		.attr 'width', barWidth
		.attr 'height', (d) -> negs_y(d.length) - (c.height + c.mb)

	# kde

	line = d3.line()
		.curve d3.curveBasis
		.x (d) -> x d[0]
		.y (d) -> y d[1]

	legend = chart.append 'g'
		.attr 'class', 'legend'
		.attr 'transform', 'translate(8, 14)'
	kdeWidth = d3.scaleLinear()
		.range [8, 2, 1]
		.domain [0, 2, 3]
	kdeOpacity = d3.scaleLinear()
		.range [0.4, 1, 1]
		.domain [0, 2, 3]
	kdeDash = (x) -> {0: '', 1: '', 2: '', 3: '4'}[x]

	for category in allCategoryKdes
		unless category.lft <= a.lft and a.rght <= category.rght and a.tree_id == category.tree_id
			continue

		kdePts = d3.zip kdeXs, category.kdeYs

		chart.append 'path'
			.attr 'class', 'kde'
			.attr 'stroke-width', kdeWidth category.level
			.attr 'stroke-opacity', kdeOpacity category.level
			.attr 'stroke-dasharray', kdeDash category.level
			.attr 'd', line(kdePts).replace /(\.\d)\d+/g, '$1'

		h = 22 * (category.level + 1)
		name = if category.level then category.name else 'All tossups'
		legendCategory = legend.append 'g'
			.attr 'transform', 'translate(0, ' + h + ')'
		legendCategory.append 'path'
			.attr 'class', 'kde'
			.attr 'stroke-width', kdeWidth category.level
			.attr 'stroke-opacity', kdeOpacity category.level
			.attr 'stroke-dasharray', kdeDash category.level
			.attr 'd', "M 0,0 L 30,0"
		legendCategory.append 'text'
			.text name
			.attr 'x', '78'
			.attr 'dx', 6*category.level
			.attr 'y', '0'
		legendCategory.append 'text'
			.text category.count
			.attr 'x', '68'
			.attr 'y', '0'
			.attr 'text-anchor', 'end'
			.attr 'font-size', 'smaller'
			# .attr 'font-weight', '300'
		legendCategory.append 'text'
			.text '†'
			.attr 'x', '68'
			.attr 'y', '0'
			.attr 'class', 'dag'

	# legend
	legend.append 'g'
		.attr 'class', 'bar'
		.append 'rect'
		.attr 'x', '0'
		.attr 'y', '-6'
		.attr 'width', '30'
		.attr 'height', '12'
	legend.append 'text'
		.text 'Correct buzzes'
		.attr 'x', '78'
		.attr 'y', '0'
	legend.append 'text'
		.text gets.length
		.attr 'x', '68'
		.attr 'y', '0'
		.attr 'text-anchor', 'end'
		.attr 'font-size', 'smaller'
		# .attr 'font-weight', '300'

	ng = chart.append 'g'
		.attr 'class', 'legend'
		.attr 'transform', 'translate(8, ' + (2 * c.height + c.mb - 14) + ')'
	ng.append 'rect'
		.attr 'class', 'bar neg'
		.attr 'x', '0'
		.attr 'y', '-6'
		.attr 'width', '30'
		.attr 'height', '12'
	ng.append 'text'
		.text 'Incorrect buzzes'
		.attr 'x', '78'
		.attr 'y', '0'
	ng.append 'text'
		.text negs.length
		.attr 'x', '68'
		.attr 'y', '0'
		.attr 'text-anchor', 'end'
		.attr 'font-size', 'smaller'
		# .attr 'font-weight', '300'

	# labels

	ftp = 0.84
	pwds = a.power_words / a.words

	xaxis = d3.axisBottom x
		# .tickValues [.5, .84, 1]
		# .tickValues [0, .2, .4, .6, .8, 1, pwds]
		# .tickFormat (x) -> if x is ftp then 'FTP' else if x is pwds then '*' else d3.format('0%') x
		# .tickFormat d3.format('.0%')
		.tickFormat d3.format('.2f') # see formatBzPct
		.ticks 4
		.tickSize -c.height
		.tickSizeOuter 0
	negs_xaxis = d3.axisTop x
		.ticks 4
		.tickSize -c.height
		.tickSizeOuter 0

	yaxis = d3.axisRight y
		.ticks 4
		.tickSize -c.width
		.tickSizeOuter 0
	negs_yaxis = d3.axisRight negs_y
		.ticks 4
		.tickSize -c.width
		.tickSizeOuter 0

	noAxisDefault = (g) ->
		g
			.attr 'font-size', null
			.attr 'font-family', null
			.attr 'fill', null
			.select('.domain').remove()

	# commented?
	chart.append 'g'
		.attr 'class', 'y axis'
		.attr 'transform', 'translate(' + (c.width) + ',0)'
		.call yaxis
		.call noAxisDefault
		.append 'text'
		.attr 'class', 'label'
		.text 'Buzzes'
		.attr 'text-anchor', 'middle'
		.attr 'transform', 'translate(' + 40 + ',' + (c.height/2) + ') rotate(-90)'

	chart.append 'g'
		.attr 'class', 'y axis'
		.attr 'transform', 'translate(' + (c.width) + ',0)'
		.call negs_yaxis
		.call noAxisDefault
		.append 'text'
		.attr 'class', 'label'
		.text 'Incorrect buzzes'
		.attr 'text-anchor', 'middle'
		.attr 'transform', 'translate(' + 40 + ',' + (3*c.height/2 + c.mb) + ') rotate(-90)'

	chart.append 'g'
		.attr 'class', 'x axis'
		.attr 'transform', 'translate(0,' + c.height + ')'
		.call xaxis
		.call noAxisDefault
		.append 'text'
		.attr 'class', 'label'
		.text 'Position in tossup'
		.attr 'transform', 'translate(' + c.width/2 + ',40)'

	chart.append 'g'
		.attr 'class', 'x axis'
		.attr 'transform', 'translate(0,' + (c.height + c.mb) + ')'
		.call negs_xaxis
		.call noAxisDefault
		.selectAll '.tick text'
		.remove()

	box = [
		d3.quantile(gets, 0.2),
		d3.quantile(gets, 0.4),
		d3.quantile(gets, 0.5),
		d3.quantile(gets, 0.6),
		d3.quantile(gets, 0.8)
	]
	xbox = box.map x

	framePathD =
		'M0,' + c.height  + 'L0,0'
	if gets.length > 1
		framePathD +=
		'H'   + xbox[0] + 'V-4'    +
		'H'   + xbox[1] + 'V-8'    +
		'H'   + xbox[2] + 'V0 V-8' +
		'H'   + xbox[3] + 'V-4'    +
		'H'   + xbox[4] + 'V0'
	framePathD +=
		'H'   + c.width   +
		'V'   + c.height  +
		'H0Z'
	chart.append("path")
		.attr("d", framePathD)
		.attr("fill", "none")
		.attr("stroke", "black")
		.attr("transform", 'translate(0.5, 0.5)')
	chart.append("path")
		.attr("d", 'M0,' + (c.height + c.mb) + 'H' + c.width + 'v' + c.height + 'H0Z')
		.attr("fill", "none")
		.attr("stroke", "black")
		.attr("transform", 'translate(0.5, 0.5)')

	if gets.length <= 1
		return

	topaxisg = chart.append("g")
		.attr("font-size","10")
		.attr("text-anchor","start")
	if true
		lh = if xbox[1] - xbox[0] > 7 then -6 else -10
		txt = topaxisg.append("text")
			.attr("transform", 'translate(' + ( 3 + xbox[0] ) + ',' + lh + ') rotate(-90)')
		txt.append("tspan").text("20% of").attr("x","0").attr("dy","-8")
		txt.append("tspan").text("buzzes").attr("x","0").attr("dy","8")
	if (xbox[1] - xbox[0] > 9 and xbox[2] - xbox[1] > 9)
		topaxisg.append("text")
			.text("40%")
			.attr("transform", 'translate(' + ( 3 + xbox[1] ) + ',-10) rotate(-90)')
	if (xbox[2] - xbox[1] > 9 or xbox[1] - xbox[0] > 9)
		topaxisg.append("text")
			.text("Median")
			.attr("transform", 'translate(' + ( 3 + xbox[2] ) + ',-10) rotate(-90)')
	if (xbox[3] - xbox[2] > 9 and xbox[4] - xbox[3] > 9)
		topaxisg.append("text")
			.text("60%")
			.attr("transform", 'translate(' + ( 3 + xbox[3] ) + ',-10) rotate(-90)')
	if (xbox[4] - xbox[3] > 9 or xbox[3] - xbox[2] > 9)
		lh = if xbox[4] - xbox[3] > 7 then -6 else -10
		topaxisg.append("text")
			.text("80%")
			.attr("transform", 'translate(' + ( 3 + xbox[4] ) + ',' + lh + ') rotate(-90)')

	x # hack return

window.copy_lightweight = (el) ->
	text_url = el.dataset.text.replace('__url__', window.location.href);
	clipboard.writeText text_url
