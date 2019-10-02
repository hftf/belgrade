question_set_result = '
	<div class="typeahead-result typeahead-set" data-href="{{url}}">
		<div>
			<a href={{url}}>{{name}}</a>
		</div>
	</div>'

tossup_result = '
	<div class="typeahead-result" data-href={{url}}>
		<div>
			<b class="typeahead-secondary-text typeahead-model">Tossup</b>
			<span class="typeahead-secondary-text typeahead-score"><span style="width: {{width}}px;"></span> {{score}}</span>
			<a href={{url}}>{{{name}}}</a>
		</div>
		<div class="typeahead-secondary-text typeahead-editions">
			<span>Editions: </span>
			{{#each editions}}
				<a href={{url}}>{{name}}</a> 
			{{/each}}
		</div>
	</div>'

bonus_result = '
	<div class="typeahead-result" data-href={{url}}>
		<div>
			<b class="typeahead-secondary-text typeahead-model">Bonus</b>
			<span class="typeahead-secondary-text typeahead-score"><span style="width: {{width}}px;"></span> {{score}}</span>
			<a href={{url}}>{{{name}}}</a>
		</div>
		<div class="typeahead-secondary-text typeahead-editions">
			<span>Editions: </span>
			{{#each editions}}
				<a href={{url}}>{{name}}</a> 
			{{/each}}
		</div>
	</div>'

team_result = '
	<div class="typeahead-result" data-href={{url}}>
		<div>
			<b class="typeahead-secondary-text typeahead-model">Team</b>
			<span class="typeahead-secondary-text typeahead-score"><span style="width: {{width}}px;"></span> {{score}}</span>
			<a href={{url}}>{{{name}}}</a>
		</div>
		<div class="typeahead-secondary-text typeahead-editions">
			<span>at {{tournament}}</span>
		</div>
	</div>'

player_result = '
	<div class="typeahead-result" data-href={{url}}>
		<div>
			<b class="typeahead-secondary-text typeahead-model">Player</b>
			<span class="typeahead-secondary-text typeahead-score"><span style="width: {{width}}px;"></span> {{score}}</span>
			<a href={{url}}>{{{name}}}</a>
		</div>
		<div class="typeahead-secondary-text typeahead-editions">
			<span>on team {{team}} @ {{tournament}}</span>
		</div>
	</div>'

module.exports =
	question_set_result: question_set_result
	tossup_result:       tossup_result
	bonus_result:        bonus_result
	team_result:         team_result
	player_result:       player_result
