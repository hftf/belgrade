question_set_result = '
	<div class="typeahead-result typeahead-set" data-href="{{url}}">
		<div>
			<a href={{url}}>{{name}}</a>
		</div>
	</div>'

tossup_result = '
	<div class="typeahead-result" data-href={{url}}>
		<div>
			<b class="typeahead-secondary typeahead-model">Tossup</b>
			<span class="typeahead-secondary typeahead-score"><span style="width: {{width}}px;"></span> {{score}}</span>
			<a href={{url}}>{{{name}}}</a>
		</div>
		{{#if neditions}}
		<div class="typeahead-secondary typeahead-editions">
			<span class="typeahead-model">Editions</span>
			{{#each editions}}
				<a href={{url}}>{{name}}</a> 
			{{/each}}
		</div>
		{{/if}}
		<div class="typeahead-secondary typeahead-editions">
			<span class="typeahead-model">{{packet}}, T{{position}}</span>
			<span>{{#if author}}{{author}}, {{/if}}{{category}}</span>
		</div>
	</div>'

bonus_result = '
	<div class="typeahead-result" data-href={{url}}>
		<div>
			<b class="typeahead-secondary typeahead-model">Bonus</b>
			<span class="typeahead-secondary typeahead-score"><span style="width: {{width}}px;"></span> {{score}}</span>
			<a href={{url}}>{{{name}}}</a>
		</div>
		{{#if neditions}}
		<div class="typeahead-secondary typeahead-editions">
			<span class="typeahead-model">Editions</span>
			{{#each editions}}
				<a href={{url}}>{{name}}</a> 
			{{/each}}
		</div>
		{{/if}}
		<div class="typeahead-secondary typeahead-editions">
			<span class="typeahead-model">{{packet}}, B{{position}}</span>
			<span>{{#if author}}{{author}}, {{/if}}{{category}}</span>
		</div>
	</div>'

team_result = '
	<div class="typeahead-result" data-href={{url}}>
		<div>
			<b class="typeahead-secondary typeahead-model">Team</b>
			<span class="typeahead-secondary typeahead-score"><span style="width: {{width}}px;"></span> {{score}}</span>
			<a href={{url}}>{{{name}}}</a>
		</div>
		<div class="typeahead-secondary typeahead-editions">
			<span class="typeahead-model">At site</span>
			<span>{{tournament}}</span>
		</div>
	</div>'

player_result = '
	<div class="typeahead-result" data-href={{url}}>
		<div>
			<b class="typeahead-secondary typeahead-model">Player</b>
			<span class="typeahead-secondary typeahead-score"><span style="width: {{width}}px;"></span> {{score}}</span>
			<a href={{url}}>{{{name}}}</a>
		</div>
		<div class="typeahead-secondary typeahead-editions">
			<span class="typeahead-model">On team</span>
			<span>{{team}} @ {{tournament}}</span>
		</div>
	</div>'

module.exports =
	question_set_result: question_set_result
	tossup_result:       tossup_result
	bonus_result:        bonus_result
	team_result:         team_result
	player_result:       player_result
