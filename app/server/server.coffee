express = require 'express'
NamedRouter = require 'named-routes'
compression = require 'compression'

fs = require 'fs'
util = require 'util'
glob = require 'glob'

R = require 'ramda'
sqlite = require 'better-sqlite3'
moment = require 'moment'

HTML2BBCode = require('html2bbcode').HTML2BBCode
h2b_s = new HTML2BBCode()
h2b = (h) ->
	h2 = h
		.join('\n')
		.replace(/span class="s1">|span>/g, 'u>')
		.replace(/<\/rb><rp>/g, '</rb><span style="color:#58c">')
		.replace(/<\/rp><\/ruby>/g, '</span></ruby>')
		.replace(/<\/?rp>/g, '')
	h2b_s.feed(h2).toString()
HTML2Markdown = require('turndown')
h2m_s = new HTML2Markdown()
escapes = [
	[/\\/g,    '\\\\'],
	[/\*/g,    '\\*'],
	[/`/g,     '\\`'],
	[/_/g,     '\\_'],
	[/^(\d+)\. /g, '$1\\. ']
]
h2m_s.escape = (string) ->
	escapes.reduce ((accumulator, escape) ->
		accumulator.replace(escape[0], escape[1])
		), string
h2m = (h) ->
	h2 = h
		.join('\n')
		.replace(/span class="s1">|span>/g, 'u>')
	h2m_s.addRule 'underline', 
		filter: ['u']
		replacement: (v) -> '__' + v + '__'
	h2m_s.turndown(h2).toString()
		.replace(/ANSWER: ([^\n]+)/g, 'ANSWER: || $1 ||') # || = spoiler tag for Discord

red = (s) -> '\x1b[91;1m[ERROR] ' + s + '\x1b[0m';
console.error = R.compose console.error, red

kde = require '../client/coffee/kde'
d3 = require 'd3'

allQueries = require './queries'


# Example: npm start --port=3002 --dbfname=fo19.db.sqlite3
port = process.env.npm_config_port || 3000
dbfname = process.env.npm_config_dbfname || 'db.sqlite3'
dbfbase = process.env.npm_config_dbfbase || '/Users/ophir/Documents/quizbowl/every.buzz/every_buzz/'
bundlebase = process.env.npm_config_bundlebase || '/Users/ophir/Documents/quizbowl/oligodendrocytes/bundles/%s/%s/html/'

dbpath = dbfbase + dbfname
db = new sqlite dbpath, { readonly: true }


formatDate = (date) ->
	dateMoment = moment date
	"#{dateMoment.fromNow()} (#{dateMoment.format('LL, LT')})"
statstats = () ->
	files = new glob.Glob 'app/**', sync: true, stat: true
	mtimes = R.pluck 'mtime', files.statCache
	latest = Object.keys(mtimes).reduce (a, b) -> if mtimes[a] > mtimes[b] then a else b
	return
		dbpath_mtime:   formatDate fs.statSync(dbpath).mtime
		file_mtime:     formatDate mtimes[latest]
		filepath_mtime: latest
		filename_mtime: latest.replace process.cwd(), ''


# TODO rename
META = {
	'filename_template': bundlebase,
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

scan_packet = (packet_filename, question_type, question_number) ->
	packet_file = fs.readFileSync(packet_filename, 'utf8').split('\n')

	for line, index in packet_file
		if line.startsWith(util.format(META[question_type]['line_startswith_template'], question_number))
			return [
				packet_file.slice(index, index + 1).join('\n'),
				packet_file.slice(index + 1, index + 1 + META[question_type]['get_next_n_lines']).join('\n')
			]
# END NEW

sim = require 'string-similarity'
striptags = require 'striptags'

# compute difference between two strings
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
basePath = server.locals.basePath =
	(pathStr) ->
		server.settings.basePath + pathStr

namedRouter = new NamedRouter
namedRouter.extendExpress router
namedRouter.registerAppHelpers server

router.use compression()

router.use express.static './dist'
router.use '/images', express.static './app/images'

server.set 'view engine', 'pug'
server.set 'views', './app/server/pug'
# server.locals.pretty = '\t'


router.get '/question_sets/index.json', 'question_sets_index', (req, res, next) ->
	queries =
		set: ['all', allQueries.question_sets.question_sets_index]

	try
		results = runQueries queries

		sets = R.map ((qs) -> 
			name: qs.name
			url: basePath namedRouter.build 'question_set', { question_set_slug: qs.slug }, 'get'
		), results.set

		res.setHeader 'Content-Type', 'application/json'
		res.send JSON.stringify(sets)
	catch err
		res.status 500
		res.send err.stack

router.get '/question_sets/:question_set_slug/index.json', 'question_set_index', (req, res, next) ->
	id = id: req.params.question_set_slug

	queries =
		pages: ['all', allQueries.question_set.question_set_index,  id]
		
	try
		results = runQueries queries
		pages = []

		keepKey = (v, k) -> !R.test(/(id|(?<!edition)_slug)$/, k)
		for result in results.pages
			page = JSON.parse result.page
			page.url = basePath namedRouter.build page.model, page
			page.slug = page[page.model + '_slug']
			page = R.pickBy keepKey, page
			pages.push page

		res.setHeader 'Content-Type', 'application/javascript'
		res.send JSON.stringify(pages)
	catch err
		res.status 500
		res.send err.stack

router.get '/question_sets/', 'question_sets', (req, res, next) ->
	queries =
		question_sets: ['all', allQueries.question_sets.question_sets]
		
	try
		results = runQueries queries

		results.statstats = statstats()

		res.render 'question_sets.pug', results
	catch err
		res.status 500
		res.send err.stack

router.get '/question_sets/:question_set_slug/', 'question_set', (req, res, next) ->
	params =
		question_set_slug: req.params.question_set_slug

	queries =
		question_set: ['get', allQueries.question_set.question_set, params]
		editions:     ['all', allQueries.question_set.editions,     params]

	try
		results = runQueries queries

		res.render 'question_set.pug', results
	catch err
		res.status 500
		res.send err.stack

router.get '/question_sets/:question_set_slug/notes.html', 'question_set_notes', (req, res, next) ->
	params =
		question_set_slug: req.params.question_set_slug

	queries =
		question_set: ['get', allQueries.question_set.question_set, params]
		tossups:      ['all', allQueries.question_set.tossup_notes, params]
		bonuses:      ['all', allQueries.question_set.bonus_notes, params]

	try
		results = runQueries queries

		results['tossups'].map (buzz) ->
			url_params = { ...buzz, question_set_slug: results['question_set']['question_set_slug'] }
			buzz.team_url   = namedRouter.build('team', url_params)
			buzz.player_url = namedRouter.build('player', url_params)
		results['bonuses'].map (geb) ->
			url_params = { ...geb, question_set_slug: results['question_set']['question_set_slug'] }
			geb.team_url   = namedRouter.build('team', url_params)
			# geb.bonus_url = namedRouter.build('bonus', url_params)

		res.render 'notes.pug', results
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
				url_params = { ...team, question_set_slug: results['edition']['question_set_slug'], tournament_site_slug: tournament['tournament_site_slug'] }
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
		results['bbcode']   = h2b results['raw']
		results['markdown'] = h2m results['raw']
		results['buzzes'].map (buzz) ->
			buzz.class = classifyBuzz(buzz)
			url_params = { ...buzz, question_set_slug: results['tossup']['question_set_slug'] }
			buzz.team_url   = namedRouter.build('team', url_params)
			buzz.player_url = namedRouter.build('player', url_params)
			url_params.team_slug = buzz.opponent_slug
			buzz.opponent_url = namedRouter.build('team', url_params)

		for edition in results['editions']
			unless edition['rollup'] or edition['question_ptr_id'] == id.id
				try
					edition_raw = get_question_html('tossup', edition)
					edition.similarity = similarity(edition_raw, results['raw'])
				catch err
					edition.similarity = '?'

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
		results['bbcode']   = h2b results['raw']
		results['markdown'] = h2m results['raw']
		for edition in results['editions']
			unless edition['rollup'] or edition['question_ptr_id'] == id.id
				try
					edition_raw = get_question_html('bonus', edition)
					edition.similarity = similarity(edition_raw, results['raw'])
				catch err
					edition.similarity = '?'

		res.render 'bonus.pug', results
	catch err
		res.status 500
		res.send err.stack


router.get '/question_sets/:question_set_slug/tournaments/:tournament_site_slug/teams/:team_slug.html', 'team', (req, res, next) ->
	params =
		question_set_slug    : req.params.question_set_slug
		tournament_site_slug : req.params.tournament_site_slug
		team_slug            : req.params.team_slug

	id = id:
		db.prepare allQueries.team.te_id
		.get params
		.id
	queries =
		team: ['get', allQueries.team.team, id]
		buzzes: ['all', allQueries.team.buzzes, id]
		bonuses: ['all', allQueries.team.bonuses, id]
		categories: ['all', allQueries.perf.categories, params]

	try
		results = runQueries queries

		results['team']['players'] = JSON.parse results['team']['players']
		for player in results['team']['players']
			url_params = { ...player, question_set_slug: results['team']['question_set_slug'], tournament_site_slug: results['team']['tournament_site_slug'], team_slug: results['team']['team_slug'] }
			player.player_url = namedRouter.build('player', url_params)
		results['buzzes'].map (buzz) ->
			buzz.class = classifyBuzz(buzz)
			url_params = { ...buzz, question_set_slug: results['team']['question_set_slug'] }
			buzz.tossup_url = namedRouter.build('tossup', url_params)
			buzz.player_url = namedRouter.build('player', url_params)
			url_params.team_slug = buzz.opponent_slug
			buzz.opponent_url = namedRouter.build('team', url_params)
		results['bonuses'].map (geb) ->
			url_params = { ...geb, question_set_slug: results['team']['question_set_slug'] }
			geb.bonus_url = namedRouter.build('bonus', url_params)
			url_params.team_slug = geb.opponent_slug
			geb.opponent_url = namedRouter.build('team', url_params)

		res.render 'team.pug', results
	catch err
		res.status 500
		res.send err.stack

router.get '/question_sets/:question_set_slug/tournaments/:tournament_site_slug/teams/:team_slug/players/:player_slug.html', 'player', (req, res, next) ->
	params =
		question_set_slug    : req.params.question_set_slug
		tournament_site_slug : req.params.tournament_site_slug
		team_slug            : req.params.team_slug
		player_slug          : req.params.player_slug

	id = id:
		db.prepare allQueries.player.pl_id
		.get params
		.id
	queries =
		player: ['get', allQueries.player.player, id]
		buzzes: ['all', allQueries.player.buzzes, id]

	try
		results = runQueries queries

		results['buzzes'].map (buzz) ->
			buzz.class = classifyBuzz(buzz)
			url_params = { ...buzz, question_set_slug: results['player']['question_set_slug'] }
			buzz.tossup_url = namedRouter.build('tossup', url_params)
			url_params.team_slug = buzz.opponent_slug
			buzz.opponent_url = namedRouter.build('team', url_params)

		res.render 'player.pug', results
	catch err
		res.status 500
		res.send err.stack


router.get '/question_sets/:question_set_slug/editions/:question_set_edition_slug/tossups/:tossup_slug.js', 'tossup_data', (req, res, next) ->
	params =
		question_set_slug         : req.params.question_set_slug
		question_set_edition_slug : req.params.question_set_edition_slug
		tossup_slug               : req.params.tossup_slug

	id = id:
		db.prepare allQueries.tossup.t_id
		.get params
		.question_ptr_id
	
	queries =
		a: ['get', allQueries.tossup_data.a, id]
		b: ['all', allQueries.tossup.buzzes, id] # note: same query is used for tossup view

	try
		results = runQueries queries

		results.a.p = JSON.parse results.a.p
		results.a.p.sort()
		results.a.n = JSON.parse results.a.n
		results.a.n.sort()
		results.b = results.b.map (buzz) -> p: buzz.buzz_location, v: buzz.buzz_value, bb: buzz.bounceback

		res.setHeader 'Cache-Control', 'public, max-age=3600'
		res.setHeader 'Content-Type', 'application/javascript'
		res.send "window.tossup = #{JSON.stringify(results)};";
	catch err
		res.status 500
		res.send err.stack

router.get '/question_sets/:question_set_slug/categories.js', 'categories', (req, res, next) ->
	slug = question_set_slug: req.params.question_set_slug

	queries =
		d: ['all', allQueries.categories.d, slug]

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

router.get '/licensing.html', 'licensing', (req, res, next) ->
	res.render 'licensing.pug'

router.get '/', 'home', (req, res, next) ->
	queries =
		ticker: ['get', allQueries.home.ticker]
	try
		results = runQueries queries
		res.render 'home.pug', results

server.use '/jank', router
# server.use router

server.use '/fonts', express.static './dist/fonts'

server.listen port, ->
	console.log 'server listening on port ' + port
	return
