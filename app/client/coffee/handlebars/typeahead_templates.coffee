set_result = '
	<div class="typeahead-result typeahead-set" data-href="{{url}}">
		<div>
			<a href={{url}}>{{name}}</a>
		</div>
	</div>'

tossup_result = '
	<div class="typeahead-result" data-href={{url}}>
		<div>
			<a href={{url}}>{{{name}}}</a> <span class="typeahead-secondary-text">Tossup</span><span class="typeahead-secondary-text typeahead-score">{{score}}</span>
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
			<a href={{url}}>{{{name}}}</a> <span class="typeahead-secondary-text">Bonus</span><span class="typeahead-secondary-text typeahead-score">{{score}}</span>
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
			<a href={{url}}>{{{name}}}</a> <span class="typeahead-secondary-text">Team</span><span class="typeahead-secondary-text typeahead-score">{{score}}</span>
		</div>
		<div class="typeahead-secondary-text typeahead-editions">
			<span>Played @ {{tournament}}</span>
		</div>
	</div>'

player_result = '
	<div class="typeahead-result" data-href={{url}}>
		<div>
			<a href={{url}}>{{{name}}}</a> <span class="typeahead-secondary-text">Player</span><span class="typeahead-secondary-text typeahead-score">{{score}}</span>
		</div>
		<div class="typeahead-secondary-text typeahead-editions">
			<span>Played for {{team}} @ {{tournament}}</span>
		</div>
	</div>'

module.exports =
	set_result:    set_result
	tossup_result: tossup_result
	bonus_result:  bonus_result
	team_result:   team_result
	player_result: player_result
