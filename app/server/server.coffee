express = require 'express'
NamedRouter = require 'named-routes'

R = require 'ramda'
q = require 'q'
sqlite = require 'sqlite3'
sql = require 'q-sqlite3'

red = (s) -> '\x1b[91;1m[ERROR] ' + s + '\x1b[0m';
console.error = R.compose console.error, red

kde = require '../client/coffee/kde'
d3 = require 'd3'

allQueries = require './queries'


dbfname = '/Users/ophir/Documents/quizbowl/every.buzz/every_buzz/db.sqlite3'
db = new sql.Database new sqlite.Database dbfname


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
classifyBuzz = (buzz) ->
	if buzz.buzz_value <= 0
		'neg'
	else if buzz.bounceback != null # == 'bounceback'
		'bb' #bounceback-get
	else
		'get'

runQueries = (queries) ->
	runQuery = ([method, query...]) -> db[method].apply db, query
	pf = R.compose q.all, R.map runQuery
	pf R.values queries
		.then R.zipObj R.keys queries

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
router.use '/img', express.static './app/img'

server.set 'view engine', 'jade'
server.set 'views', './app/server/jade'
# server.locals.pretty = '\t'


router.get '/question_sets/', 'question_sets', (req, res, next) ->
	queries =
		question_sets: ['all', allQueries.question_sets.question_sets]
	runQueries queries
		.then (results) ->
			res.render 'question_sets.jade', results
		.catch (err) ->
			res.status 500
			res.send err.stack

router.get '/question_sets/:question_set_slug/', 'question_set', (req, res, next) ->
	id = req.params.question_set_slug

	queries =
		question_set: ['get', allQueries.question_set.question_set, id]
		tossups:      ['all', allQueries.question_set.tossups,      id]
		bonuses:      ['all', allQueries.question_set.bonuses,      id]
	runQueries queries
		.then (results) ->
			for type in ['tossups', 'bonuses']
				results[type + 'ByEdition'] = R.groupBy R.prop('question_set_edition'), results[type]
				delete results[type]

			res.render 'question_set.jade', results
		.catch (err) ->
			res.status 500
			res.send err.stack

router.get '/question_sets/:question_set_slug/editions/:question_set_edition_slug/tossups/:tossup_slug.html', 'tossup', (req, res, next) ->
	params =
		$question_set_slug         : req.params.question_set_slug
		$question_set_edition_slug : req.params.question_set_edition_slug
		$tossup_slug               : req.params.tossup_slug

	db.get allQueries.tossup.t_id, params
		.then (result) ->
			id = result.question_ptr_id

			queries =
				tossup:   ['get', allQueries.tossup.tossup,   id]
				buzzes:   ['all', allQueries.tossup.buzzes,   id]
				editions: ['all', allQueries.tossup.editions, id]

			runQueries queries
		.then (results) ->
			results['raw'] = get_question_html('tossup', results['tossup'])
			results['buzzes'].map (buzz) -> buzz.class = classifyBuzz(buzz)

			res.render 'tossup.jade', results
		.catch (err) ->
			res.status 500
			res.send err.stack

router.get '/question_sets/:question_set_slug/editions/:question_set_edition_slug/bonuses/:bonus_slug.html', 'bonus', (req, res, next) ->
	params =
		$question_set_slug         : req.params.question_set_slug
		$question_set_edition_slug : req.params.question_set_edition_slug
		$bonus_slug                : req.params.bonus_slug

	db.get allQueries.bonus.b_id, params
		.then (result) ->
			id = result.question_ptr_id

			queries =
				bonus:        ['get', allQueries.bonus.bonus,        id]
				performances: ['all', allQueries.bonus.performances, id]
				editions:     ['all', allQueries.bonus.editions,     id]

			runQueries queries
		.then (results) ->
			results['raw'] = get_question_html('bonus', results['bonus'])

			res.render 'bonus.jade', results
		.catch (err) ->
			res.status 500
			res.send err.stack

router.get '/js/tossups/:question_ptr_id.js', 'tossup_data', (req, res, next) ->
	id = req.params.question_ptr_id
	
	queries =
		a: ['get', allQueries.tossup_data.a, id]
		b: ['all', allQueries.tossup.buzzes, id]

	runQueries queries
		.then (results) ->
			results.a.p = JSON.parse results.a.p
			results.a.p.sort()
			results.a.n = JSON.parse results.a.n
			results.a.n.sort()

			res.setHeader 'Cache-Control', 'public, max-age=3600'
			res.setHeader 'Content-Type', 'application/javascript'
			res.send "window.tossup = #{JSON.stringify(results)};";
		.catch (err) ->
			res.status 500
			res.send err.stack

router.get '/js/categories/:question_set_id.js', 'categories', (req, res, next) ->
	id = req.params.question_set_id

	queries =
		d: ['all', allQueries.categories.d, id]

	runQueries queries
		.then (results) ->
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
		.catch (err) ->
			res.status 500
			res.send err.stack

router.get '/notices.html', 'notices', (req, res, next) ->
	res.render 'notices.jade'

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
