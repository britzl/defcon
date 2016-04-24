return [[
<html>
<head>
	<!--<script src="console.js" type="text/javascript"></script>-->
	<script type="text/javascript">
		function send(data) {
			console.log("send")
			var log = document.getElementById('log');
			var command = document.getElementById('command').value;
			log.value = log.value + "> " + command + "\n"

			var url = "http://localhost:8098/console/" + encodeURIComponent(command);
			var xhr = new XMLHttpRequest();
			xhr.open("GET", url);
			xhr.responseType = "json";
			xhr.onload = function() {
				if (xhr.status === 0
				 || xhr.status >= 200 && xhr.status < 300
				 || xhr.status === 304) {
					var response = unescape(xhr.response.response);
					if (response == null) {
						response = ""
					}
					response = response.split("+").join(" ")
					console.log("response " + response)
					log.value = log.value + response + "\n"
					log.scrollTop = log.scrollHeight;
				}
				else {
					console.log("status " + xhr.statusText)
					log.value = log.value + xhr.statusText;
					log.scrollTop = log.scrollHeight;
				}
			};
			xhr.onerror = function() {
				console.log("onerror called")
				log.value = log.value + xhr.statusText;
				log.scrollTop = log.scrollHeight;
			};
			xhr.send(null);
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
<body bgcolor="#2D2F31" style="padding: 20px">
	<div class="box">
		<textarea id="log" readonly></textarea>
		<input type="text" id="command" onkeydown="if (event.keyCode == 13) { send(document.getElementById('command').value); return false; }" placeholder="&gt;"/>
	</div>
</body>
</html>
]]
