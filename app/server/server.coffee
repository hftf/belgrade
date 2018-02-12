express = require 'express'
R = require 'ramda'
q = require 'q'
sqlite = require 'sqlite3'
sql = require 'q-sqlite3'

red = (s) -> '\x1b[91;1m[ERROR] ' + s + '\x1b[0m';
console.error = R.compose console.error, red


dbfname = 'app/data/db'
dbfname = '/Users/ophir/Documents/quizbowl/every.buzz/every_buzz/db.sqlite3'
db = new sql.Database new sqlite.Database dbfname

#select b2.user, group_concat(b2.position||'/'||q2.words) from buzzes b, buzzes b2, questions q, questions q2
#where q.id = 847 and b.question = q.id and b.user = b2.user and b2.question = q2.id and q2.category = q.category group by b2.user;
q1 = 'select user u, cast(position as int) p, correct c, answer a \
from buzzes \
where question = ?1 order by correct desc, p'

q2 = 'select q.*, group_concat(b.p) p, o \
from questions q, \
(select group_concat(q2.id) o from questions q, questions q2 \
	where q.id = ?1 and q2.id != q.id and q.answer = q2.answer), \
(select round(avg(b.position*1.0/q2.words),3) p \
	from questions q, questions q2, buzzes b \
	where q.id = ?1 and q.category = q2.category and q2.id = b.question \
	group by q2.id order by p) \
as b where q.id = ?1;'

# NEW 
q1 = 'select player_id u, buzz_location p, (case when buzz_value > 0 then 1 else 0 end) c, case when answer_given is not null then answer_given else "" end a \
from schema_gameeventtossup \
where tossup_id = ?1 and buzz_location is not null and buzz_value > 0 order by c desc, p'
# buzz_location is not null

q2 = 'select t.*, q.*, p.*, c.name as category,
group_concat(round(get.p * 1.0 / t.words, 3)) p,
cget.p o
from 
schema_tossup t, schema_question q, schema_packet p, schema_category c,
(select buzz_location p from schema_gameeventtossup get where get.tossup_id = ?1 and buzz_value > 0 order by p) get,
(select group_concat(round(get.buzz_location * 1.0 / t.words, 3)) p from schema_gameeventtossup get, schema_tossup t, schema_question q,
   schema_question q_aux, schema_tossup t_aux, schema_category c
   where t_aux.question_ptr_id = ?1 and q_aux.category_id = c.id and q_aux.id = t_aux.question_ptr_id
   and get.tossup_id = t.question_ptr_id and q.id = t.question_ptr_id
   and buzz_value > 0 order by p) cget
where t.question_ptr_id = ?1 and t.question_ptr_id = q.id and q.category_id = c.id and q.packet_id = p.id
;'
# , schema_category cp
# q.category_id >= cp.lft and q.category_id <= cp.rght
   # and cp.level = 1 and cp.lft <= c.lft and cp.rght >= c.rght
# group_concat(round(negs.p * 1.0 / words, 3))
# (select buzz_location p from schema_gameeventtossup get where get.tossup_id = ?1 and buzz_value < 0 order by p) negs


# TODO rename
META = {
    'filename_template': '/Users/ophir/Documents/quizbowl/oligodendrocytes/bundled-packets/regionals18-packets/html/',
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
get_question_html = (packet_filename, question_type, question_number) ->
    # TODO Hardcoded
    packet_filename = META['filename_template'] + packet_filename
    return scan_packet(packet_filename, question_type, question_number)

fs = require('fs')
util = require('util')
scan_packet = (packet_filename, question_type, question_number) ->
    packet_file = fs.readFileSync(packet_filename, 'utf8').split('\n')

    for line, index in packet_file
        if line.startsWith(util.format(META[question_type]['line_startswith_template'], question_number))
            return packet_file.slice(index, index + META[question_type]['get_next_n_lines']).join('\n')
# END NEW

runQueries = (queries) ->
	runQuery = ([method, query...]) -> db[method].apply db, query
	pf = R.compose q.all, R.map runQuery
	pf R.values queries
		.then R.zipObj R.keys queries

server = express()
server.use express.static './dist'
server.use '/img', express.static './app/img'



server.use '/test/:id', (req, res, next) ->
	id = req.params.id
	
	queries =
		a: ['get', q2, id]
		b: ['all', q1, id]

	split = (x) -> JSON.parse "[" + x + "]"
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
			results['a']['raw'] = get_question_html(results['a']['filename'], 'tossup', results['a']['position'])

			res.setHeader 'Content-Type', 'application/json'
			res.send results
		.catch (err) ->
			res.status 500
			res.send err.stack


port = 3000
server.listen port, ->
	console.log 'server listening on port ' + port
	return
