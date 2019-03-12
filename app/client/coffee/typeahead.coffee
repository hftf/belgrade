$ = require('jquery')
handlebars = require('handlebars')
typeahead_templates = require('./handlebars/typeahead_templates')
constants = require('./constants')

isQuestion = (page_type) ->
    page_type == 'tossup' || page_type == 'bonus'

renderTypeahead = (input, arr, searchTerm, perSetLimit, onClick) ->
    init = () ->
        $('.typeahead-results').remove()

        if arr.length > 0
            templates = 
                set: handlebars.compile(typeahead_templates.set_result)
                tossup: handlebars.compile(typeahead_templates.tossup_result)
                bonus: handlebars.compile(typeahead_templates.bonus_result)
                team: handlebars.compile(typeahead_templates.team_result)
                player: handlebars.compile(typeahead_templates.player_result)

            menu = $('<div />', 'class': 'typeahead-results').appendTo($(input).parent())

            arr.forEach (set) ->
                menu.append (
                    templates["set"]
                        url: "/jank" + set.set_url
                        name: set.set_name
                )

                currentEditions = []
                currentTeamCount = 0
                mainLink = ''
                resultCount = 0
                searchTermRegExp = new RegExp('(' + searchTerm + ')', 'gi')

                set.set_results.forEach (result, index, array) ->
                    if resultCount <  perSetLimit
                        if result && isQuestion(result.page_type)
                            currentEditions.push
                                url: "/jank" + result.url
                                name: result.edition_slug.substring(5)

                            if result.team_count > currentTeamCount
                                mainLink = result.url
                                currentTeamCount = result.team_count
                            
                            if index + 1 == array.length || result.slug != array[index + 1].slug
                                menu.append (
                                    templates[result.page_type]
                                        url: "/jank" + mainLink
                                        name: result.name.replace(searchTermRegExp, '<span class="underline">$1</span>');
                                        score: result.score
                                        editions: currentEditions
                                )
                                
                                currentEditions = []
                                mainLink = ''
                                currentTeamCount = 0
                                resultCount = resultCount + 1
                        else if result && result.page_type != 'set'
                            menu.append (
                                templates[result.page_type]
                                    url: "/jank" + result.url
                                    name: result.name.replace(searchTermRegExp, '<span class="underline">$1</span>');
                                    score: result.score
                                    team: result.team_name
                                    tournament: result.tournament_name
                            )
                            resultCount = resultCount + 1                        

                return
    
    addEvents = () ->
        $('html').off 'click'
        $('.search').off 'keydown'
        $('.typeahead-result').off 'click'
        $('.typeahead-result').off 'mouseover'

        $('html').on 'click', (e) ->
            if !$(e.target).hasClass('.typeahead-results') && $(e.target).parents(".typeahead-results").length == 0
                $('.typeahead-results').remove()
            return

        $('.search').on 'keydown', (e) ->
            currentActive = $('.typeahead-result.typeahead-active')
            target = null
            
            if e.which == constants.keyCode.DOWN
                target = $(currentActive).next()
            else if e.which == constants.keyCode.UP
                target = $(currentActive).prev()
            else if e.which == constants.keyCode.ENTER
                $('.typeahead-result.typeahead-active').trigger('click')
            
            if target
                $(currentActive).removeClass('typeahead-active')

                if $(target).length
                    $(target).addClass('typeahead-active')
                else
                    firstOrLast = if e.which == constants.keyCode.DOWN then 'first' else 'last'
                    $('.typeahead-result:' + firstOrLast).addClass('typeahead-active')

            return

        $('.typeahead-result').on 'click', (e) ->
            onClick e

        return

    init()
    addEvents()

    return

module.exports = renderTypeahead