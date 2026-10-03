extends Node
## Talks to the Scareathon arcade page that hosts this game in an iframe, with
## the same protocol as 8 Bit Evil Returns:
##   game -> page  {type: "unityReady"}
##   page -> game  {type: "SCARATHON_USER", userId, accessToken, apiBaseUrl}
## Once signed in we fetch the player's avatar look and username.
## Outside a browser (editor, desktop) everything here is a no-op.

signal signed_in
signal look_loaded(look: Dictionary)

var user_id := ""
var user_name := ""
var access_token := ""
var api_base := ""
var look := {}  # {profile: {skin, hair, eyes}, outfit: [{item, dyes}]}
var _on_message: JavaScriptObject

## Dev flags from the command line (`-- --room=mire`) or the page URL
## (`?room=mire&outfit=alex`). Bare flags are "1".
func flags() -> Dictionary:
	var out := {}
	var parts: Array = []
	for a in OS.get_cmdline_user_args():
		parts.append(a.trim_prefix("--"))
	if is_web():
		var q = JavaScriptBridge.eval("location.search")
		if q is String and q.length() > 1:
			parts.append_array(q.substr(1).split("&"))
	for part in parts:
		var kv: PackedStringArray = part.split("=", true, 1)
		out[kv[0]] = kv[1].uri_decode() if kv.size() > 1 else "1"
	return out

func is_web() -> bool:
	return OS.has_feature("web")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_web():
		return
	_on_message = JavaScriptBridge.create_callback(_handle_message)
	var window := JavaScriptBridge.get_interface("window")
	window.addEventListener("message", _on_message)
	_post_to_page({"type": "unityReady"})

func _handle_message(args: Array) -> void:
	var data = args[0].data
	if data == null or typeof(data) != TYPE_OBJECT or str(data.type) != "SCARATHON_USER":
		return
	user_id = str(data.userId)
	access_token = str(data.accessToken)
	api_base = str(data.apiBaseUrl).trim_suffix("/")
	signed_in.emit()
	_request("%s/user" % api_base, func(code, d):
		if code == 200 and d is Dictionary and d.get("data") is Dictionary:
			user_name = str(d.data.get("username", "")))
	_request("%s/user/looks?ids=%s" % [api_base, user_id], func(code, d):
		if code == 200 and d is Dictionary and d.get("data") is Dictionary and d.data.has(user_id):
			look = d.data[user_id]
			look_loaded.emit(look))

func _post_to_page(msg: Dictionary) -> void:
	if is_web():
		JavaScriptBridge.eval("window.parent && window.parent.postMessage(%s, '*')" % JSON.stringify(msg))

func _request(url: String, done: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray()
	if access_token != "":
		headers.append("Authorization: Bearer " + access_token)
	http.request_completed.connect(func(_r, code, _h, bytes: PackedByteArray):
		http.queue_free()
		if code == 401:
			_post_to_page({"type": "unityReady"})
		var parsed = JSON.parse_string(bytes.get_string_from_utf8())
		done.call(code, parsed if parsed != null else {}))
	http.request(url, headers)
