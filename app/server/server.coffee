express = require 'express'
NamedRouter = require 'named-routes'

R = require 'ramda'
sqlite = require 'better-sqlite3'

red = (s) -> '\x1b[91;1m[ERROR] ' + s + '\x1b[0m';
console.error = R.compose console.error, red

kde = require '../client/coffee/kde'
d3 = require 'd3'

allQueries = require './queries'


dbfname = '/Users/ophir/Documents/quizbowl/every.buzz/every_buzz/db.sqlite3'
db = new sqlite dbfname, { readonly: true }


# TODO rename
META = {
    'filename_template': '/Users/ophir/Documents/quizbowl/oligodendrocytes/bundles/%s/%s/html/',
    'tossup': {
        'line_startswith_template':  '<p class="p1 tu"><m v="0">%d.</m> ',
        'get_next_n_lines': 2, # ANSWER + <Tag>
    },
    'bonus': {
        'line_startswith_template':  '<p class="p1 bonus">%d. ',
        'get_next_n_lines': 7, # (Part, ANSWER) × 3 + <Tag>
    },
}


# NEW
get_question_html = (question_type, question) ->
	get_question_html_(
		question_type
		question['filename'],
		question['question_set_slug'],
		question['question_set_edition_slug'],
		question['position']
	)
get_question_html_ = (question_type, packet_filename, question_set_slug, question_set_edition_slug, question_number) ->
    # TODO Hardcoded
    set_edition_path = util.format(META['filename_template'], question_set_slug, question_set_edition_slug)
    packet_filename = set_edition_path + packet_filename
    return scan_packet(packet_filename, question_type, question_number)

fs = require('fs')
util = require('util')
scan_packet = (packet_filename, question_type, question_number) ->
    packet_file = fs.readFileSync(packet_filename, 'utf8').split('\n')

    for line, index in packet_file
        if line.startsWith(util.format(META[question_type]['line_startswith_template'], question_number))
            return [
                packet_file.slice(index, index + 1),
                packet_file.slice(index + 1, index + 1 + META[question_type]['get_next_n_lines']).join('\n')
            ]
# END NEW

sim = require 'string-similarity'
striptags = require 'striptags'

similarity = (h1, h2) ->
	h1 = striptags h1, [], '\n'
	h2 = striptags h2, [], '\n'
	1 - sim.compareTwoStrings h1, h2

classifyBuzz = (buzz) ->
	if buzz.buzz_value <= 0
		'neg'
	else if buzz.bounceback != null # == 'bounceback'
		'bb' #bounceback-get
	else
		'get'

runQueries = (queries) ->
	runQuery = ([method, query, params...]) ->
		db.prepare(query)[method] params...
	R.mapObjIndexed runQuery, queries

unrollup = R.groupBy (row) -> if row.rollup then 'rollup' else 'entries'

server = express()
router = new express.Router

server.set 'basePath', '/jank'
server.locals.basePath =
	(pathStr) ->
		server.settings.basePath + pathStr

namedRouter = new NamedRouter
namedRouter.extendExpress router
namedRouter.registerAppHelpers server

router.use express.static './dist'
router.use '/images', express.static './app/images'

server.set 'view engine', 'pug'
server.set 'views', './app/server/pug'
# server.locals.pretty = '\t'


router.get '/question_sets/', 'question_sets', (req, res, next) ->
	queries =
		question_sets: ['all', allQueries.question_sets.question_sets]
		
	try
		results = runQueries queries

		res.render 'question_sets.pug', results
	catch err
		res.status 500
		res.send err.stack

router.get '/question_sets/:question_set_slug/', 'question_set', (req, res, next) ->
	id = id: req.params.question_set_slug

	queries =
		question_set: ['get', allQueries.question_set.question_set, id]
		editions:     ['all', allQueries.question_set.editions,     id]

	try
		results = runQueries queries

		res.render 'question_set.pug', results
	catch err
		res.status 500
		res.send err.stack

router.get '/question_sets/:question_set_slug/editions/:question_set_edition_slug/', 'edition', (req, res, next) ->
	params =
		question_set_slug         : req.params.question_set_slug
		question_set_edition_slug : req.params.question_set_edition_slug

	id = id:
		db.prepare allQueries.edition.qse_id
		.get params
		.id

	queries =
		edition: ['get', allQueries.edition.edition, id]
		tournaments: ['all', allQueries.edition.tournaments, id]
		tossups: ['all', allQueries.edition.tossups, id]
		bonuses: ['all', allQueries.edition.bonuses, id]

	try
		results = runQueries queries

		results['tournaments'] = unrollup results['tournaments']
		for tournament in results.tournaments.entries
			tournament.teams = JSON.parse tournament.teams
			tournament.teams = R.sortBy R.prop('team_name'), tournament.teams
			for team in tournament.teams
				url_params = { ...team, question_set_slug: results['edition']['question_set_slug'], tournament_slug: tournament['tournament_slug'] }
				team.team_url = namedRouter.build('team', url_params)

		res.render 'edition.pug', results
	catch err
		res.status 500
		res.send err.stack

router.get '/question_sets/:question_set_slug/editions/:question_set_edition_slug/tossups/:tossup_slug.html', 'tossup', (req, res, next) ->
	params =
		question_set_slug         : req.params.question_set_slug
		question_set_edition_slug : req.params.question_set_edition_slug
		tossup_slug               : req.params.tossup_slug

	id = id:
		db.prepare allQueries.tossup.t_id
		.get params
		.question_ptr_id

	queries =
		tossup:   ['get', allQueries.tossup.tossup,   id]
		buzzes:   ['all', allQueries.tossup.buzzes,   id]
		editions: ['all', allQueries.tossup.editions, id]

	try 
		results = runQueries queries

		results['raw'] = get_question_html('tossup', results['tossup'])
		results['buzzes'].map (buzz) ->
			buzz.class = classifyBuzz(buzz)
			url_params = { ...buzz, question_set_slug: results['tossup']['question_set_slug'] }
			buzz.team_url   = namedRouter.build('team', url_params)
			buzz.player_url = namedRouter.build('player', url_params)
			url_params.team_slug = buzz.opponent_slug
			buzz.opponent_url = namedRouter.build('team', url_params)

		for edition in results['editions']
			unless edition['rollup'] or edition['question_ptr_id'] == id.id
				edition_raw = get_question_html('tossup', edition)
				edition.similarity = similarity(edition_raw, results['raw'])

		res.render 'tossup.pug', results
	catch err
		res.status 500
		res.send err.stack

router.get '/question_sets/:question_set_slug/editions/:question_set_edition_slug/bonuses/:bonus_slug.html', 'bonus', (req, res, next) ->
	params =
		question_set_slug         : req.params.question_set_slug
		question_set_edition_slug : req.params.question_set_edition_slug
		bonus_slug                : req.params.bonus_slug

	id = id:
		db.prepare allQueries.bonus.b_id
		.get params
		.question_ptr_id

	queries =
		bonus:        ['get', allQueries.bonus.bonus,        id]
		performances: ['all', allQueries.bonus.performances, id]
		editions:     ['all', allQueries.bonus.editions,     id]

	try
		results = runQueries queries

		results['performances'].map (performance) ->
			url_params = { ...performance, question_set_slug: results['bonus']['question_set_slug'] }
			performance.team_url   = namedRouter.build('team', url_params)
			url_params.team_slug = performance.opponent_slug
			performance.opponent_url = namedRouter.build('team', url_params)

		results['raw'] = get_question_html('bonus', results['bonus'])
		for edition in results['editions']
			unless edition['rollup'] or edition['question_ptr_id'] == id.id
				edition_raw = get_question_html('bonus', edition)
				edition.similarity = similarity(edition_raw, results['raw'])

		res.render 'bonus.pug', results
	catch err
		res.status 500
		res.send err.stack


router.get '/question_sets/:question_set_slug/tournaments/:tournament_slug/teams/:team_slug.html', 'team', (req, res, next) ->
	params =
		question_set_slug : req.params.question_set_slug
		tournament_slug   : req.params.tournament_slug
		team_slug         : req.params.team_slug

router.get '/question_sets/:question_set_slug/tournaments/:tournament_slug/teams/:team_slug/players/:player_slug.html', 'player', (req, res, next) ->
	params =
		question_set_slug : req.params.question_set_slug
		tournament_slug   : req.params.tournament_slug
		team_slug         : req.params.team_slug
		player_slug       : req.params.player_slug


router.get '/js/tossups/:question_ptr_id.js', 'tossup_data', (req, res, next) ->
	id = id: req.params.question_ptr_id
	
	queries =
		a: ['get', allQueries.tossup_data.a, id]
		b: ['all', allQueries.tossup.buzzes, id]

	try
		results = runQueries queries

		results.a.p = JSON.parse results.a.p
		results.a.p.sort()
		results.a.n = JSON.parse results.a.n
		results.a.n.sort()

		res.setHeader 'Cache-Control', 'public, max-age=3600'
		res.setHeader 'Content-Type', 'application/javascript'
		res.send "window.tossup = #{JSON.stringify(results)};";
	catch err
		res.status 500
		res.send err.stack

router.get '/js/categories/:question_set_id.js', 'categories', (req, res, next) ->
	id = id: req.params.question_set_id

	queries =
		d: ['all', allQueries.categories.d, id]

	try
		results = runQueries queries

		domainp = [0, 1]
		deltaX = 4/(41*16) #0.005
		results.kdeXs = kdeXs = R.append 1, d3.range domainp..., deltaX
		for d in results.d
			categoryPoints =
				# R.filter R.gt(1),
				JSON.parse(d.p)
			kdeF = kde()
				.sample categoryPoints
				# .kernel (x) -> 1*+(-.5<x<.5)
				# .bandwidth 0.03
				.bounds domainp
			kdePts = kdeF kdeXs
			kdeYs = R.map ((p) -> +p[1].toFixed 4), kdePts
			d.kdeYs = kdeYs
			delete d.p

		res.setHeader 'Cache-Control', 'public, max-age=3600'
		res.setHeader 'Content-Type', 'application/javascript'
		res.send "window.allCategoryKdes = #{JSON.stringify(results)};";
	catch err
		res.status 500
		res.send err.stack

router.get '/notices.html', 'notices', (req, res, next) ->
	res.render 'notices.pug'

router.get '/', 'home', (req, res, next) ->
	res.send 'Hi'

server.use '/jank', router
# server.use router

server.get '/fonts/*', (req, res, next) ->
	res.send ''

port = 3000
server.listen port, ->
	console.log 'server listening on port ' + port
	return
