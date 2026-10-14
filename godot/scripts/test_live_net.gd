extends SceneTree
## Игра против живого сервера — только чтение, ничего не пишет:
##   GET /api/health; GET /api/launcher (1,1 КБ — сервер отдаёт его сжатым и кусками) со сжатием и без;
##   GET /api/pvp/top без входа — ждём 401 с понятным ответом.
## Печатает код ответа или вид сбоя (dns / connect / tls / timeout / read) — тот же NetHttp, что у игры.
##   bash tools/godot.sh --headless --path godot --script res://scripts/test_live_net.gd [-- api=https://civcity.ru/api]
## Запускать с включённым VPN и без него: так видно, мешает ли VPN самой игре (браузер и лаунчер ходят иначе).

var fails := 0
var api := Account.API_DEFAULT


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("api="):
			api = a.trim_prefix("api=").trim_suffix("/")
	_run.call_deferred()


func check(ok: bool, what: String, r: Dictionary) -> void:
	var how := ("код %d" % int(r["status"])) if int(r["status"]) != 0 else ("сбой %s" % String(r["net"]))
	print("LIVE %s %s — %s, %d мс%s" % ["PASS" if ok else "FAIL", what, how, int(r.get("ms", 0)), " (со второй попытки)" if r.get("retried", false) else ""])
	if not ok:
		fails += 1


func _run() -> void:
	var n := Node.new()
	root.add_child(n)
	print("LIVE сервер ", api)
	var r: Dictionary = await NetHttp.fetch(n, api, HTTPClient.METHOD_GET, "/health")
	check(int(r["status"]) == 200 and bool((r["data"] as Dictionary).get("ok", false)), "/health", r)
	for gz in [true, false]:
		r = await NetHttp.fetch(n, api, HTTPClient.METHOD_GET, "/launcher", null, "", {"accept_gzip": gz})
		check(int(r["status"]) == 200 and not (r["data"] as Dictionary).is_empty(), "/launcher %s" % ("со сжатием" if gz else "без сжатия"), r)
	r = await NetHttp.fetch(n, api, HTTPClient.METHOD_GET, "/pvp/top")
	check(int(r["status"]) == 401 and String(r["error"]) != "", "/pvp/top без входа → 401 «%s»" % String(r["error"]), r)
	print("LIVE DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
