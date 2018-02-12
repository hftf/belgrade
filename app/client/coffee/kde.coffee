science = require 'science'

module.exports = ->
	kernel = science.stats.kernel.gaussian
	sample = []
	bounds = [-Infinity, Infinity]
	bandwidth = science.stats.bandwidth.nrd

	kde = (points, j) ->
		bw = bandwidth.call(this, sample)
		points.map (x) ->
			i = -1
			y = 0
			n = sample.length

			between = (v) -> v >= bounds[0] and v < bounds[1]
			filtered = sample.filter between
			l = filtered.length

			while ++i < l
				y += kernel((x - filtered[i]) / bw)
				for bound in bounds
					y += kernel((bound + bound - x - filtered[i]) / bw)

			[
				x
				y / bw / n
			]

	kde.bounds = (x) ->
		if !arguments.length
			return bounds
		bounds = x
		kde

	kde.kernel = (x) ->
		if !arguments.length
			return kernel
		kernel = x
		kde

	kde.sample = (x) ->
		if !arguments.length
			return sample
		sample = x
		kde

	kde.bandwidth = (x) ->
		if !arguments.length
			return bandwidth
		bandwidth = science.functor(x)
		kde

	kde
