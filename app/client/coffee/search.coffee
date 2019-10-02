$ = require('jquery')
lunr = require('lunr')
renderTypeahead = require('./typeahead')
normalizer = require('lunr-unicode-normalizer')(lunr)

lunrIndex = null
index = []
perSetLimit = 5
prevQuery = ''

initLunr = ->
	$.getJSON('/jank/question_sets/index.json').done (sets) ->
		deferreds = []

		sets.forEach (set) ->
			deferreds.push( $.getJSON(set.url + 'index.json')
				.done (results) ->
					set.pages = results
				.fail (xhr, status, error) ->
					console.log "Failed to load search index for #{set.name} (Status: #{xhr.status}). You may not be authorized."
			)

		$.when.apply(null, deferreds).done ->
			index = sets

			for set in index
				set.lunrIndex = lunr () ->
					@field 'name'
					@ref 'url'
					
					@pipeline.remove(lunr.trimmer)
					@pipeline.remove(lunr.stemmer)

					for page in set.pages
						@add page

	.fail (xhr, status, error) ->
		console.log "Failed to load main search index."

search = (query) ->
	index.map (set) ->
		# something goes wrong on Safari https://github.com/olivernn/lunr.js/issues/279
		queryResults = set.lunrIndex.query (q) ->
			q.term lunr.tokenizer(query), boost: 10, wildcard: lunr.Query.wildcard.LEADING | lunr.Query.wildcard.TRAILING
			# q.term lunr.tokenizer(query), boost: 100
			# q.term lunr.tokenizer(query), boost: 33, wildcard: lunr.Query.wildcard.TRAILING
		# need to look up again because lunr.Index.query only returns ref instead of whole document
		# TODO this should really be constant lookup
		queryMatches = queryResults.map (result) ->
			match = set.pages.find( (page) -> page.url == result.ref )
			if match
				match.score = result.score
				return match
			# else shouldn't happen
		.filter (e) -> e

		name: set.name
		url: set.url
		set_results: queryMatches
	.filter (set) ->
		return set.set_results.length > 0

initUI = ->
	$('.search').keyup ->
		query = $(this).val()
		
		if query == prevQuery
			return

		if query.length < 2
			$('.typeahead-results').remove()
			return
		
		prevQuery = query
		results = search(query.trim())
		renderTypeahead '.search', results, query, perSetLimit, (e) ->
			destination = $(e.target).data 'href'

			if !destination
				destination = $(e.target).parents('.typeahead-result').first().data 'href'
			
			window.location.href = destination

initLunr()
$(document).ready ->
	initUI()
