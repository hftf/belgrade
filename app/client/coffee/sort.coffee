$  = require('jquery')
dt = require('datatables.net')($)

$(document).ready () ->
	options =
		info: true
		paging: false
		pageLength: 20
		lengthChange: false
		autoWidth: false
		stateSave: true

	$ '.dataTable'
		.DataTable options
