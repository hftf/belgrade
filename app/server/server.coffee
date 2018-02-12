express = require 'express'
R = require 'ramda'
q = require 'q'
sqlite = require 'sqlite3'
sql = require 'q-sqlite3'

red = (s) -> '\x1b[91;1m[ERROR] ' + s + '\x1b[0m';
console.error = R.compose console.error, red


dbfname = 'app/data/db'
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

			res.setHeader 'Content-Type', 'application/json'
			res.send results
		.catch (err) ->
			res.status 500
			res.send err.stack


port = 3000
server.listen port, ->
	console.log 'server listening on port ' + port
	return
