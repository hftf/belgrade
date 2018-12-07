express = require 'express'
R = require 'ramda'
q = require 'q'
sqlite = require 'sqlite3'
sql = require 'q-sqlite3'

red = (s) -> '\x1b[91;1m[ERROR] ' + s + '\x1b[0m';
console.error = R.compose console.error, red

kde = require '../client/coffee/kde'
d3 = require 'd3'

dbfname = '/Users/ophir/Documents/quizbowl/every.buzz/every_buzz/db.sqlite3'
db = new sql.Database new sqlite.Database dbfname


# NEW 

q_ = '
SELECT
    c.name, c.lft, c.rght, c.level,
    count(*) as count,
    json_group_array(round(get.buzz_location * 1.0 / t.words, 3)) p
FROM
    schema_category c,
    schema_category cp,
    schema_question q,
    schema_tossup t,
    schema_gameeventtossup get
WHERE
    q.category_id = cp.id
    AND c.lft <= cp.lft AND cp.rght <= c.rght
    AND get.tossup_id = t.question_ptr_id AND q.id = t.question_ptr_id
    AND buzz_location IS NOT NULL AND buzz_value > 0
GROUP BY
    c.id
;'

q1 = 'select
te.name team_name,
p.name player_name,
buzz_value,
buzz_location p,
case when buzz_location is null then "" else printf("%.0f%%", buzz_location * 100.0 / words) end buzz_location_pct,
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
and tossup_id = ?1 order by buzz_location is null, buzz_location, bounceback, buzz_value desc'
# buzz_location is not null

q2 = 'select t.*, q.*,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
qse.date as question_set_edition,
c.name as category, c.lft, c.rght, c.level,
(select max(question_ptr_id) from schema_tossup where question_ptr_id < t.question_ptr_id) prev,
(select min(question_ptr_id) from schema_tossup where question_ptr_id > t.question_ptr_id) next
from 
schema_tossup t, schema_question q, schema_packet p, schema_category c, schema_questionsetedition qse
where t.question_ptr_id = ?1 and t.question_ptr_id = q.id and q.category_id = c.id and q.packet_id = p.id and p.question_set_edition_id = qse.id
;'
q2b = 'select t.*, q.*,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
qse.date as question_set_edition,
c.name as category, c.lft, c.rght, c.level,
(select json_group_array(round(buzz_location * 1.0 / t.words,3)) from schema_gameeventtossup get where get.tossup_id = t.question_ptr_id and buzz_location is not null and buzz_value > 0) p,
(select json_group_array(round(buzz_location * 1.0 / t.words,3)) from schema_gameeventtossup get where get.tossup_id = t.question_ptr_id and buzz_location is not null and buzz_value <= 0) n
from 
schema_tossup t, schema_question q, schema_packet p, schema_category c, schema_questionsetedition qse
where t.question_ptr_id = ?1 and t.question_ptr_id = q.id and q.category_id = c.id and q.packet_id = p.id and p.question_set_edition_id = qse.id
;'
# , schema_category cp
# q.category_id >= cp.lft and q.category_id <= cp.rght
   # and cp.level = 1 and cp.lft <= c.lft and cp.rght >= c.rght
# group_concat(round(negs.p * 1.0 / words, 3))
# (select buzz_location p from schema_gameeventtossup get where get.tossup_id = ?1 and buzz_value < 0 order by p) negs

fakerollup = (select, group) ->
	"SELECT null AS rollup, #{select} #{group} UNION ALL SELECT 1 as rollup, #{select}"

qs = fakerollup('t.*, q.*,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
c.name as category, a.name as author, a.initials,
qse.date as question_set_edition,
COUNT(CASE WHEN get.buzz_value = 15 THEN 1 END) count15,
COUNT(CASE WHEN get.buzz_value = 10 THEN 1 END) count10,
COUNT(CASE WHEN get.buzz_value = -5 THEN 1 END) countN5,
COUNT(CASE WHEN get.buzz_value =  0 THEN 1 END) count0,
COUNT(CASE WHEN get.buzz_value >  0 THEN 1 END) countG,
COUNT(DISTINCT game_id) AS countRooms,
COUNT(DISTINCT CASE WHEN get.buzz_location THEN game_id END) AS countRoomsBzPt,
COUNT(CASE WHEN get.buzz_value    IS NOT NULL THEN 1 END) AS countBzs,
COUNT(CASE WHEN get.buzz_location IS NOT NULL THEN 1 END) AS countBzPts,
round(AVG(CASE WHEN get.buzz_value > 0 THEN get.buzz_location END * 1.0 / t.words), 3) avgBzPt,
round(min(CASE WHEN get.buzz_value > 0 THEN get.buzz_location END * 1.0 / t.words), 3) firstBzPt
from 
schema_tossup t0, schema_question q0, 
schema_tossup t, schema_question q, schema_packet p, schema_questionsetedition qse, schema_category c, schema_author a
LEFT JOIN schema_gameeventtossup get ON get.tossup_id = t.question_ptr_id 
LEFT JOIN schema_gameevent ge ON ge.id = get.gameevent_ptr_id 
LEFT JOIN schema_gameteam gt ON ge.game_team_id = gt.id
LEFT JOIN schema_game g ON gt.game_id = g.id
where t0.question_ptr_id = ?1 and t0.question_ptr_id = q0.id
and 2 <=
(t0.answer like t.answer) +
(q0.category_id = q.category_id)
and t.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id
and q.category_id = c.id and q.author_id = a.id',
'GROUP BY t.question_ptr_id')

qlt = 'select t.*, q.*,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
qse.name as question_set_edition,
c.name as category, a.name as author, a.initials
from
schema_tossup t, schema_question q, schema_packet p, schema_questionsetedition qse, schema_category c, schema_author a
where t.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id and q.category_id = c.id and q.author_id = a.id
;'
qlb = 'select b.*, q.*,
b.answer1||" / "||b.answer2||" / "||b.answer3 as answers,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
qse.name as question_set_edition,
c.name as category, a.name as author, a.initials
from
schema_bonus b, schema_question q, schema_packet p, schema_questionsetedition qse, schema_category c, schema_author a
where b.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id and q.category_id = c.id and q.author_id = a.id
;'

qb1 = 'select
te.name team_name,
geb.*,
value1+value2+value3 as total,
tou.site_name tournament_name,
rm.number room_number,
r.number round_number
from schema_gameeventbonus geb, schema_bonus b, schema_team te, schema_tournament tou,
schema_gameevent ge, schema_gameteam gt, schema_game g, schema_round r, schema_room rm \
where ge.id = geb.gameevent_ptr_id and ge.game_team_id = gt.id and gt.game_id = g.id
and g.round_id = r.id and g.room_id = rm.id and te.tournament_id = tou.id
and geb.bonus_id = b.question_ptr_id and gt.team_id = te.id \
and bonus_id = ?1 order by total desc, value1 desc, value2 desc, value3 desc
;'
qb = 'select b.*, q.*,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
qse.date as question_set_edition, c.name as category,
(select max(question_ptr_id) from schema_bonus where question_ptr_id < b.question_ptr_id) prev,
(select min(question_ptr_id) from schema_bonus where question_ptr_id > b.question_ptr_id) next
from 
schema_bonus b, schema_question q, schema_packet p, schema_category c, schema_questionsetedition qse
where b.question_ptr_id = ?1 and b.question_ptr_id = q.id and q.category_id = c.id and q.packet_id = p.id and p.question_set_edition_id = qse.id
;'

qbs = fakerollup('b.*, q.*,
b.answer1||" / "||b.answer2||" / "||b.answer3 as answers,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
c.name as category, a.name as author, a.initials,
qse.date as question_set_edition,
AVG(total)/30 avgT,
AVG(value1)/10 avg1,
AVG(value2)/10 avg2,
AVG(value3)/10 avg3,
COUNT(CASE WHEN total = 0  THEN 1 END) count0,
COUNT(CASE WHEN total = 10 THEN 1 END) count10,
COUNT(CASE WHEN total = 20 THEN 1 END) count20,
COUNT(CASE WHEN total = 30 THEN 1 END) count30,
COUNT(CASE WHEN total >= 0  THEN 1 END) atleast0,
COUNT(CASE WHEN total >= 10 THEN 1 END) atleast10,
COUNT(CASE WHEN total >= 20 THEN 1 END) atleast20,
COUNT(CASE WHEN total >= 30 THEN 1 END) atleast30,
COUNT(DISTINCT game_id) AS countRooms
from 
schema_bonus b0, schema_question q0, 
schema_bonus b, schema_question q, schema_packet p, schema_questionsetedition qse, schema_category c, schema_author a
LEFT JOIN (SELECT *, value1+value2+value3 AS total FROM schema_gameeventbonus) geb ON geb.bonus_id = b.question_ptr_id 
LEFT JOIN schema_gameevent ge ON ge.id = geb.gameevent_ptr_id 
LEFT JOIN schema_gameteam gt ON ge.game_team_id = gt.id
LEFT JOIN schema_game g ON gt.game_id = g.id
where b0.question_ptr_id = ?1 and b0.question_ptr_id = q0.id
and 2 <=
(b0.answer1 like b.answer1) +
(b0.answer2 like b.answer2) +
(b0.answer3 like b.answer3) +
(q0.category_id = q.category_id)
and b.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id
and q.category_id = c.id and q.author_id = a.id',
'GROUP BY b.question_ptr_id')

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
get_question_html = (question_type, question) ->
	get_question_html_(
		question_type
		question['filename'],
		question['question_set_edition'],
		question['position']
	)
get_question_html_ = (question_type, packet_filename, question_set_edition_date, question_number) ->
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
		tossups: ['all', qlt]
		bonuses: ['all', qlb]
	runQueries queries
		.then (results) ->
			for type of results
				results[type + 'ByEdition'] = R.groupBy R.prop('question_set_edition'), results[type]
				delete results[type]

			res.render 'index.jade', results
		.catch (err) ->
			res.status 500
			res.send err.stack

server.use '/tossup/:id.html', (req, res, next) ->
	id = req.params.id
	queries =
		tossup: ['get', q2, id]
		buzzes: ['all', q1, id]
		editions: ['all', qs, id]

	runQueries queries
		.then (results) ->
			results['raw'] = get_question_html('tossup', results['tossup'])
			results['buzzes'].map (buzz) -> buzz.class = classifyBuzz(buzz)

			res.render 'tossup.jade', results
		.catch (err) ->
			res.status 500
			res.send err.stack

server.use '/bonus/:id.html', (req, res, next) ->
	id = req.params.id
	queries =
		bonus: ['get', qb, id]
		performances: ['all', qb1, id]
		editions: ['all', qbs, id]

	runQueries queries
		.then (results) ->
			results['raw'] = get_question_html('bonus', results['bonus'])

			res.render 'bonus.jade', results
		.catch (err) ->
			res.status 500
			res.send err.stack

server.use '/tossup/:id.js', (req, res, next) ->
	id = req.params.id
	
	queries =
		a: ['get', q2b, id]
		b: ['all', q1, id]
		c: ['all', qs, id]

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

server.use '/categories.js', (req, res, next) ->
	queries =
		d: ['all', q_]

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


port = 3000
server.listen port, ->
	console.log 'server listening on port ' + port
	return
