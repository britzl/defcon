local M = {}

local header =  [[
<html>
<head>]]
local script = [[<script type="text/javascript">
		var command_history = [];
		var command_index = 0;
		function send(data) {
			var log = document.getElementById('log');
			var command = document.getElementById('command').value;
			log.value = log.value + "> " + command + "\n"

			var url = window.location.protocol + "//" + window.location.host + "/console/" + encodeURIComponent(command);

			fetch(url).then(function(response) {
				var reader = response.body.getReader();
				var decoder = new TextDecoder();
				var log = document.getElementById('log');
				var partial = "";
				function read() {
					return reader.read().then(function(result) {
						partial += decoder.decode(result.value || new Uint8Array, {
							stream: !result.done
						});
						
						var complete = partial.split(/(?:,|\r\n)/);
						if (!result.done) {
							partial = complete[complete.length - 1];
							complete = complete.slice(0, -1);
						}
						for (var data of complete) {
							if (data.length > 0) {
								try {
									var response = unescape(JSON.parse(data).response);
									if (response == null) {
										response = ""
									}
									response = response.split("+").join(" ")
									log.value = log.value + response + "\n"
									log.scrollTop = log.scrollHeight;
								}
								catch(err) {
									console.log("err" + err);
								}
							}
						}

						if (result.done) {
							return;
						}
						
						return read();
					})
				}
	
				return read();
			});
		}
		function move_cursor_to_end(el) {
			setTimeout(function() {
				if (typeof el.selectionStart == "number") {
					el.selectionStart = el.selectionEnd = el.value.length;
				} else if (typeof el.createTextRange != "undefined") {
					el.focus();
					var range = el.createTextRange();
					range.collapse(false);
					range.select();
				}
			}, 10);
		}		
		function handlekeydown(event) {
			if (event.keyCode == 13) {
				var command = document.getElementById('command').value
				if (command != "") {
					send(command);
					if (command_history.length == 0 || command_history[command_history.length - 1] != command) {
						command_history.push(command);
					}
					command_index = 0;
					document.getElementById('command').value = '';
				}
				return false;
			}
			else if (event.keyCode == 38 || event.keyCode == 40) {
				if (command_history.length > 0) {
					command_index = command_index + (event.keyCode == 38 ? -1 : 1);
					command_index = command_index % command_history.length;
					if (command_index < 0) {
						command_index += command_history.length;
					}
					document.getElementById('command').value = command_history[command_index];
				}
				move_cursor_to_end(document.getElementById('command'));
			}
			else if (event.keyCode == 9) {
				event.preventDefault();
				let command_el = document.getElementById('command')
				let command = command_el.value

				// Get the last searched command, or store this one.
				let last_command = localStorage.last_command_text
				if (last_command == null) {
					localStorage.last_command_text = command
					last_command = command
				}

				// Generate a suggestion.
				let items = document.getElementById('commands')
				let suggestions = [];
				for (const item of items.options) {
					if (item.value.startsWith(last_command)){
						var match = last_command + item.value.replace(last_command, "").split(".")[0]
						suggestions.push(match)
					}
				}
				let unique_suggestions = [...new Set(suggestions)];
				unique_suggestions.sort()
				// Increment the index
				let index = localStorage.last_command_index;
				index = (index == null) ? 0 : parseInt(index)
				if (index > unique_suggestions.length - 1) {
					// If our index is bigger than our suggestion list
					// restore the command and reset the index.
					command_el.value = last_command
					index = -1
				}
				else {
					let new_text = unique_suggestions[index]
					if (new_text) {
						command_el.value = new_text
					}
				}
				localStorage.last_command_index = (index + 1).toString()
			}
			else if (event.keyCode != 9) {
				localStorage.removeItem("last_command_text")
				localStorage.last_command_index = "0"
			}
		}
		window.onbeforeunload = () => {
			localStorage.clear()
		}
	</script>]]
local style = [[<style>
		.box {
			display: flex;
			flex-flow: column;
			height: 100%;
		}
		body {
			background-color: #2D2F31;
			padding: 2px;
		}
		#log {
			font-family: 'Lucida Console', Monaco, monospace;
			font-size: 20;
			width: 100%;
			height: 100%;
			padding: 15px;
			margin: 0px;
			color: #C5C8C6;
			background-color: #1D1F21;
			border: none;
			resize: none;
			outline: none;
		}
		#command {
			font-family: 'Lucida Console', Monaco, monospace;
			font-size: 20px;
			padding: 15px;
			margin: 0px;
			width: 100%;
			height: 50px;
			color: #C5C8C6;
			background-color: #1D1F21;
			border: none;
			outline: none;
		}
	</style>
	</head>
]]
local content = [[<body onload="document.getElementById('command').focus()">
	<div class="box">
		<textarea onkeydown="handlekeydown(event)" id="log" readonly></textarea>
		<input type="text" id="command" onkeydown="handlekeydown(event)" placeholder="&gt;"/>
		%s
	</div>]]
		
local footer = [[</body>
</html>]]

function M.html(commands)
	local data_list = ""
	if next(commands) ~= nil then
		data_list = [[<datalist id="commands">]]
		for name, _ in pairs(commands) do
			data_list = data_list .. [[<option value="]] .. name .. [[" />]]
		end
		data_list = data_list .. [[</datalist>]]
	end
	return header .. script .. style .. string.format(content, data_list) .. footer
end

return M