express = require 'express'
R = require 'ramda'
q = require 'q'
sqlite = require 'sqlite3'
sql = require 'q-sqlite3'

red = (s) -> '\x1b[91;1m[ERROR] ' + s + '\x1b[0m';
console.error = R.compose console.error, red


dbfname = '/Users/ophir/Documents/quizbowl/every.buzz/every_buzz/db.sqlite3'
db = new sql.Database new sqlite.Database dbfname


# NEW 
q1 = 'select
te.name team_name,
p.name player_name,
buzz_value,
buzz_location p,
case when buzz_location is null then "" else printf("%.2f", buzz_location * 1.0 / words) end buzz_location_pct,
bounceback,
answer_given,
protested,
tou.site_name tournament_name,
rm.number room_number,
r.number round_number
from schema_gameeventtossup get, schema_tossup t, schema_player p, schema_team te, schema_tournament tou,
schema_gameevent ge, schema_gameteam gt, schema_game g, schema_round r, schema_room rm \
where ge.id = get.gameevent_ptr_id and ge.game_team_id = gt.id and gt.game_id = g.id
and g.round_id = r.id and g.room_id = rm.id and te.tournament_id = tou.id
and get.tossup_id = t.question_ptr_id and get.player_id = p.id and p.team_id = te.id \
and tossup_id = ?1 order by buzz_location is null, buzz_location, buzz_value desc, bounceback'
# buzz_location is not null

q2 = 'select t.*, q.*,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
qse.date as question_set_edition,
c.name as category,
group_concat(round(get.p * 1.0 / t.words, 3)) p,
cget.p o
from 
schema_tossup t, schema_question q, schema_packet p, schema_category c, schema_questionsetedition qse
left join (select buzz_location p from schema_gameeventtossup get where get.tossup_id = ?1 and buzz_value > 0 order by p) get
left join (select group_concat(round(get.buzz_location * 1.0 / t.words, 3)) p from schema_gameeventtossup get, schema_tossup t, schema_question q,
   schema_question q_aux, schema_tossup t_aux, schema_category c
   where t_aux.question_ptr_id = ?1 and q_aux.category_id = c.id and q_aux.id = t_aux.question_ptr_id
   and get.tossup_id = t.question_ptr_id and q.id = t.question_ptr_id
   and buzz_value > 0 order by p) cget
where t.question_ptr_id = ?1 and t.question_ptr_id = q.id and q.category_id = c.id and q.packet_id = p.id and p.question_set_edition_id = qse.id
;'
# , schema_category cp
# q.category_id >= cp.lft and q.category_id <= cp.rght
   # and cp.level = 1 and cp.lft <= c.lft and cp.rght >= c.rght
# group_concat(round(negs.p * 1.0 / words, 3))
# (select buzz_location p from schema_gameeventtossup get where get.tossup_id = ?1 and buzz_value < 0 order by p) negs

qs = 'select t.*, q.*,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
c.name as category, a.name as author, a.initials,
qse.date as question_set_edition
from 
schema_tossup t0, schema_question q0, 
schema_tossup t, schema_question q, schema_packet p, schema_questionsetedition qse, schema_category c, schema_author a
where t0.question_ptr_id = ?1 and t0.question_ptr_id = q0.id and t0.answer like t.answer and q0.category_id = q.category_id
and t.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id
and q.category_id = c.id and q.author_id = a.id
;'

ql = 'select t.*, q.*,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
qse.name as question_set_edition,
c.name as category, a.name as author, a.initials
from
schema_tossup t, schema_question q, schema_packet p, schema_questionsetedition qse, schema_category c, schema_author a
where t.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id and q.category_id = c.id and q.author_id = a.id
;'


# TODO rename
META = {
    'filename_template': '/Users/ophir/Documents/quizbowl/oligodendrocytes/bundled-packets/sgi-%s-packets/html/',
    # 'filename_template': '/Users/ophir/Documents/quizbowl/oligodendrocytes/bundled-packets/regionals18-packets/html/',
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
get_question_html = (packet_filename, question_set_edition_date, question_type, question_number) ->
    # TODO Hardcoded
    set_edition_path = util.format(META['filename_template'], question_set_edition_date)
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
server.use express.static './dist'
server.use '/img', express.static './app/img'


server.set 'view engine', 'jade'
server.set 'views', './app/server/jade'
server.use '/index.html', (req, res, next) ->
	queries =
		tossups: ['all', ql]
	runQueries queries
		.then (results) ->
			res.render 'index.jade', results
		.catch (err) ->
			res.status 500
			res.send err.stack

server.use '/tu.html', (req, res, next) ->
	id = req.query.id
	queries =
		tossup: ['get', q2, id]
		buzzes: ['all', q1, id]
		editions: ['all', qs, id]

	runQueries queries
		.then (results) ->
			results['raw'] = get_question_html(
				results['tossup']['filename'],
				results['tossup']['question_set_edition'],
				'tossup',
				results['tossup']['position']
			)
			results['buzzes'].map (buzz) -> buzz.class = classifyBuzz(buzz)


			res.render 'tossup.jade', results
		.catch (err) ->
			res.status 500
			res.send err.stack

server.use '/test/:id', (req, res, next) ->
	id = req.params.id
	
	queries =
		a: ['get', q2, id]
		b: ['all', q1, id]
		c: ['all', qs, id]

	split = (x) -> JSON.parse "[" + (if x then x else '') + "]"
	lensPath = (path) -> R.lens R.path(path), R.assocPath(path)
	overPaths = R.curry (f, paths, obj) ->
		R.reduce \
			(o, lens) -> R.over lens, f, o,
			obj,
			R.map lensPath, paths

	paths = R.map R.unnest, ['ao', 'ap']

	runQueries queries
		.then (results) ->
			results = overPaths split, paths, results
			results['a']['raw'] = get_question_html(results['a']['filename'], results['a']['question_set_edition'], 'tossup', results['a']['position'])

			res.setHeader 'Content-Type', 'application/json'
			res.send results
		.catch (err) ->
			res.status 500
			res.send err.stack


port = 3000
server.listen port, ->
	console.log 'server listening on port ' + port
	return
