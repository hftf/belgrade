
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

t_id = 'select t.question_ptr_id
from schema_tossup t, schema_question q, schema_packet p, schema_questionsetedition qse, schema_questionset qs
where t.slug = $tossup_slug and qse.slug = $question_set_edition_slug and qs.slug = $question_set_slug
and t.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id and qse.question_set_id = qs.id
';
b_id = 'select b.question_ptr_id
from schema_bonus b, schema_question q, schema_packet p, schema_questionsetedition qse, schema_questionset qs
where b.slug = $bonus_slug and qse.slug = $question_set_edition_slug and qs.slug = $question_set_slug
and b.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id and qse.question_set_id = qs.id
';

q1 = 'select
te.name team_name,
pl.name player_name,
buzz_value,
buzz_location p,
case when buzz_location is null then "" else printf("%.0f%%", buzz_location * 100.0 / words) end buzz_location_pct,
bounceback,
answer_given,
protested,
te2.name opponent,
tou.site_name tournament_name,
rm.number room_number,
r.number round_number
from schema_gameeventtossup get, schema_tossup t, schema_player pl, schema_team te, schema_tournament tou,
schema_gameevent ge, schema_gameteam gt, schema_game g, schema_round r, schema_room rm,
schema_gameteam gt2, schema_team te2
where ge.id = get.gameevent_ptr_id and ge.game_team_id = gt.id and gt.game_id = g.id
and gt2.game_id = g.id and gt2.id != gt.id and gt2.team_id = te2.id
and g.round_id = r.id and g.room_id = rm.id and te.tournament_id = tou.id
and get.tossup_id = t.question_ptr_id and get.player_id = pl.id and pl.team_id = te.id
and tossup_id = ?1 order by buzz_location is null, buzz_location, bounceback, buzz_value desc'
# buzz_location is not null

q2 = 'select t.*, q.*,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
qse.date as question_set_edition,
qse.slug as question_set_edition_slug,
qs.slug as question_set_slug,
qs.name as question_set,
t.slug as tossup_slug,
c.name as category, c.lft, c.rght, c.level,
(select max(question_ptr_id) from schema_tossup where question_ptr_id < t.question_ptr_id) prev,
(select min(question_ptr_id) from schema_tossup where question_ptr_id > t.question_ptr_id) next
from 
schema_tossup t, schema_question q, schema_packet p, schema_questionsetedition qse, schema_questionset qs,
schema_category c
where t.question_ptr_id = ?1
and t.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id and qse.question_set_id = qs.id
and q.category_id = c.id
;'
q2b = 'select t.*, q.*,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
qse.date as question_set_edition,
qs.name as question_set,
c.name as category, c.lft, c.rght, c.level,
(select json_group_array(round(buzz_location * 1.0 / t.words,3)) from schema_gameeventtossup get where get.tossup_id = t.question_ptr_id and buzz_location is not null and buzz_value > 0) p,
(select json_group_array(round(buzz_location * 1.0 / t.words,3)) from schema_gameeventtossup get where get.tossup_id = t.question_ptr_id and buzz_location is not null and buzz_value <= 0) n
from 
schema_tossup t, schema_question q, schema_packet p, schema_questionsetedition qse, schema_questionset qs,
schema_category c
where t.question_ptr_id = ?1
and t.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id and qse.question_set_id = qs.id
and q.category_id = c.id
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
qse.slug as question_set_edition_slug,
qs.slug as question_set_slug,
t.slug as tossup_slug,
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
schema_tossup t, schema_question q, schema_packet p, schema_questionsetedition qse, schema_questionset qs,
schema_category c, schema_author a
LEFT JOIN schema_gameeventtossup get ON get.tossup_id = t.question_ptr_id 
LEFT JOIN schema_gameevent ge ON ge.id = get.gameevent_ptr_id 
LEFT JOIN schema_gameteam gt ON ge.game_team_id = gt.id
LEFT JOIN schema_game g ON gt.game_id = g.id
where t0.question_ptr_id = ?1 and t0.question_ptr_id = q0.id
and 2 <=
(t0.answer like t.answer) +
(q0.category_id = q.category_id)
and t.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id and qse.question_set_id = qs.id
and q.category_id = c.id and q.author_id = a.id',
'GROUP BY t.question_ptr_id')

qlt = 'select t.*, q.*,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
qse.name as question_set_edition,
qse.slug as question_set_edition_slug,
qs.slug as question_set_slug,
t.slug as tossup_slug,
c.name as category, a.name as author, a.initials
from
schema_tossup t, schema_question q, schema_packet p, schema_questionsetedition qse, schema_questionset qs,
schema_category c, schema_author a
where
qs.slug = ?1
and t.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id and qse.question_set_id = qs.id
and q.category_id = c.id and q.author_id = a.id
;'
qlb = 'select b.*, q.*,
b.answer1||" / "||b.answer2||" / "||b.answer3 as answers,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
qse.name as question_set_edition,
qse.slug as question_set_edition_slug,
qs.slug as question_set_slug,
b.slug as bonus_slug,
c.name as category, a.name as author, a.initials
from
schema_bonus b, schema_question q, schema_packet p, schema_questionsetedition qse, schema_questionset qs,
schema_category c, schema_author a
where
qs.slug = ?1
and b.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id and qse.question_set_id = qs.id
and q.category_id = c.id and q.author_id = a.id
;'

qst = 'select
qs.*,
qs.slug as question_set_slug
from
schema_questionset qs
where
qs.slug = ?1
;'
qss = 'select
qs.*,
count(qse.id) as question_set_edition_count,
qs.slug as question_set_slug
from
schema_questionsetedition qse, schema_questionset qs
where
qse.question_set_id = qs.id
group by qs.id
;'

qb1 = 'select
te.name team_name,
geb.*,
value1+value2+value3 as total,
tou.site_name tournament_name,
rm.number room_number,
r.number round_number
from schema_gameeventbonus geb, schema_bonus b, schema_team te, schema_tournament tou,
schema_gameevent ge, schema_gameteam gt, schema_game g, schema_round r, schema_room rm
where ge.id = geb.gameevent_ptr_id and ge.game_team_id = gt.id and gt.game_id = g.id
and g.round_id = r.id and g.room_id = rm.id and te.tournament_id = tou.id
and geb.bonus_id = b.question_ptr_id and gt.team_id = te.id
and bonus_id = ?1 order by total desc, value1 desc, value2 desc, value3 desc
;'
qb = 'select b.*, q.*,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
qse.date as question_set_edition,
qse.slug as question_set_edition_slug,
qs.slug as question_set_slug,
qs.name as question_set,
b.slug as bonus_slug,
c.name as category,
(select max(question_ptr_id) from schema_bonus where question_ptr_id < b.question_ptr_id) prev,
(select min(question_ptr_id) from schema_bonus where question_ptr_id > b.question_ptr_id) next
from 
schema_bonus b, schema_question q, schema_packet p, schema_questionsetedition qse, schema_questionset qs,
schema_category c
where b.question_ptr_id = ?1 and b.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id and qse.question_set_id = qs.id
and q.category_id = c.id
;'

qbs = fakerollup('b.*, q.*,
b.answer1||" / "||b.answer2||" / "||b.answer3 as answers,
p.name as packet_name, p.letter as packet_letter, p.filename as filename,
c.name as category, a.name as author, a.initials,
qse.date as question_set_edition,
qse.slug as question_set_edition_slug,
qs.slug as question_set_slug,
b.slug as bonus_slug,
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
schema_bonus b, schema_question q, schema_packet p, schema_questionsetedition qse, schema_questionset qs,
schema_category c, schema_author a
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
and b.question_ptr_id = q.id and q.packet_id = p.id and p.question_set_edition_id = qse.id and qse.question_set_id = qs.id
and q.category_id = c.id and q.author_id = a.id',
'GROUP BY b.question_ptr_id')


module.exports =
	question_sets:
		question_sets: qss

	question_set:
		question_set: qst
		tossups: qlt
		bonuses: qlb

	tossup:
		t_id: t_id
		tossup: q2
		buzzes: q1
		editions: qs

	bonus:
		b_id: b_id
		bonus: qb
		performances: qb1
		editions: qbs

	tossup_data:
		a: q2b

	categories:
		d: q_
