$ = require('jquery')
lunr = require('lunr')
renderTypeahead = require('./typeahead')
normalizer = require('lunr-unicode-normalizer')(lunr)

lunrIndex = null
index = []
perSetLimit = 5
prevQuery = ''

initLunr = ->
    $.getJSON('/jank/index.json').done((sets) ->
        deferreds = []

        sets.forEach((element) -> 
            deferreds.push( $.getJSON('/jank' + element.url + 'index.json')
                .done((results) -> 
                    index.push(
                        set_name: element.name
                        set_url: element.url 
                        pages: results
                    )
                    return
                ).fail ->
                    return 
            )
        )

        $.when.apply(null, deferreds).done( ->
            index.forEach ((set) ->
                set.lunrIndex = lunr(->
                    @field 'name'
                    @ref 'url'
                    
                    @pipeline.remove(lunr.trimmer)
                    @pipeline.remove(lunr.stemmer)
                    @pipeline.remove(lunr.porterStemmer)

                    @add 
                        name: set.set_name
                        url: set.set_url
                        page_type: 'set'

                    set.pages.forEach ((page) ->
                        try
                            @add page
                        catch e
                            console.log e

                        return
                    ), this

                    return
                )
            ), this
        )

        return
    ).fail ->
        return
    return

search = (query) ->
    index.map (set) ->
        set_name: set.set_name
        set_url: set.set_url
        set_results: set.lunrIndex.query((q) ->
            q.term query, 
                boost: 100
            q.term '*' + query + '*',
                boost: 10
            
            return
        ).map (result) ->
            match = set.pages.find((page) ->
                try
                    return page.url == result.ref
                catch e
                    console.log e
                
                return
            )
            match.score = Math.floor(result.score * 100) / 100

            return match
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
            destination = $(e.target).data "href"

            if !destination
                destination = $(e.target).parents(".typeahead-result").first().data "href"
            
            window.location.href = destination
            return

initLunr()
$(document).ready ->
    initUI()
    return