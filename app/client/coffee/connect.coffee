R = require 'ramda'
d3 = require 'd3'

svgNS = 'http://www.w3.org/2000/svg'
rect = (el) -> do el.getBoundingClientRect


# sets el.name = val
attr = R.curry (el, name, val) -> el.setAttribute name, val

# sets el.name = val for each (name, val) in (names, vals)
attrs = (el, names, vals) -> R.zipWith attr(el), names, vals


brpad = 6
cc = (r) -> [r.left + r.width / 2, r.top + r.height / 2]
bc = (r) -> [r.left + r.width / 2, r.bottom + brpad]

fs =
	tuningFork: do ->
		brheight = 2
		brshort = 2
		pinshort = 4

		(svg, [h1, p], [h1r, pr]) ->
			console.log h1r, pr
			d = R.join ' ', [
				'M', h1r.left + brshort, h1r.bottom + brpad - brheight
				'l', 0, brheight
				'l', h1r.width - 2 * brshort, 0
				'l', 0, -brheight
			]

			bracket = document.createElementNS svgNS, 'path'
			line    = document.createElementNS svgNS, 'line'

			attr bracket, 'd', d
			attrs line,  ['x1', 'y1'], bc h1r
			attrs line,  ['x2', 'y2'], cc pr

			svg.appendChild bracket
			svg.appendChild line

	rug: do ->
		diagonal = d3.svg.diagonal()
		(svg, [wd], [wdR], {x}) ->
			idx = +wd.parentNode.dataset.index
			wds = +wd.parentNode.parentNode.dataset.words
			pct = idx / (wds - 1)
			buzzes = +wd.innerHTML

			path = document.createElementNS svgNS, 'path'
			line = document.createElementNS svgNS, 'line'
			circle = document.createElementNS svgNS, 'circle'

			x1 = wdR.left + wdR.width / 2
			# y1 = wdR.bottom
			y1 = wdR.top + wdR.height / 2
			x2 = x(pct) + +svg.getAttribute 'l'
			y2 = 360 + +svg.getAttribute 't'

			r = 6 + 3 * Math.sqrt buzzes

			# attrs line, ['x1', 'y1'], cc wdR
			# attrs line, ['x2', 'y2'], [0, 0]
			# attrs line, ['x1', 'y1', 'x2', 'y2'], [...]

			d = do diagonal
				.source
					x: x1
					y: y1
				.target
					x: x2
					y: y2
			attrs path, ['d', 'stroke-width'], [d, buzzes]
			attrs line, ['x1', 'y1', 'x2', 'y2', 'stroke-width'], [
				x2
				y2
				x2
				y2 + 150
				buzzes
			]
			attrs circle, ['r', 'cx', 'cy'], [r, x1 - 0.5, y1]

			svg.appendChild path
			svg.appendChild line
			svg.appendChild circle


connect = R.curry (f, svg, more, els) ->
	els_rects = R.map rect, els

	fs[f] svg, els, els_rects, more


svgGTransform = (svg) ->
	r = rect svg
	tr = 'translate(-' + r.left + ' -' + r.top + ')'
	g = document.createElementNS svgNS, 'g'
	g.setAttribute 'transform', tr
	g.setAttribute 'l', r.left
	g.setAttribute 't', r.top
	svg.appendChild g


module.exports = {
	connect
	svgGTransform
}
