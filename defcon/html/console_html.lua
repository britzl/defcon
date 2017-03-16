return [[
<html>
<head>
	<script type="text/javascript">
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
					command_history.push(command);
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
		}
	</script>
	<style>
		.box {
			display: flex;
			flex-flow: column;
			height: 100%;
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
<body bgcolor="#2D2F31" style="padding: 20px" onload="document.getElementById('command').focus()">
	<div class="box">
		<textarea id="log" readonly></textarea>
		<input type="text" id="command" onkeydown="handlekeydown(event)" placeholder="&gt;"/>
	</div>
</body>
</html>
]]
