class_name NetHttp
extends RefCounted
## Один запрос к серверу CivCity — общий для облака (Account) и боёв с городами (LegionNet).
## await NetHttp.fetch(owner, api, method, path, body, token, opts) → {status, data, error, net, ms, host, at}:
##   status — код ответа сервера; 0 — ответа нет, и тогда net — почему:
##     dns — имя сервера не нашлось; connect — не соединиться или связь оборвалась; tls — не вышло защищённое
##     соединение; timeout — долго нет ответа; read — ответ пришёл, но не читается; local:<ошибка> — запрос не ушёл.
##   opts: timeout (с, по умолчанию 20), gzip_body (сжать тело), accept_gzip (по умолчанию да),
##         safe (повторить не страшно — по умолчанию да).
## При dns / connect / tls / timeout игра забывает адрес сервера (IP.clear_cache: VPN мог его поменять, а Godot помнит
## адреса до перезапуска игры), ждёт полсекунды и пробует ещё раз. Запрос с safe = false повторяется, только если он
## точно не дошёл до сервера (имя не нашлось, соединения не было, защищённое соединение не вышло).
## Каждый сбой — строка «NET …» в журнале игры (godot.log): по ней видно настоящую причину.

const RETRY := ["dns", "connect", "tls", "timeout"]
const AGAIN := "нажмите «Повторить»"
const METHODS := ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE", "CONNECT", "PATCH"]
const RETRY_TIMEOUT := 10.0              # повтор после timeout ждёт не дольше: с новым адресом сервер отвечает быстро

## Проверки: ждать ответа не дольше стольких секунд (закрытый порт на Windows не отказывает, а молчит до тайм-аута)
static var test_timeout := 0.0


static func fetch(owner: Node, api: String, method: int, path: String, body = null, token := "", opts := {}) -> Dictionary:
	var r: Dictionary = await _once(owner, api, method, path, body, token, opts)
	if int(r["status"]) != 0 or not (String(r["net"]) in RETRY):
		return r
	if not bool(opts.get("safe", true)) and not bool(r.get("unsent", false)):
		return r                                    # мог дойти до сервера — второй раз не шлём
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return r
	IP.clear_cache(host_of(api))
	await owner.get_tree().create_timer(0.5, true, false, true).timeout
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return r
	var o2 := opts
	if String(r["net"]) == "timeout":
		o2 = opts.duplicate()
		o2["timeout"] = minf(float(opts.get("timeout", 20.0)), RETRY_TIMEOUT)
	var r2: Dictionary = await _once(owner, api, method, path, body, token, o2)
	r2["retried"] = true
	return r2


static func _once(owner: Node, api: String, method: int, path: String, body, token: String, opts: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var rq := HTTPRequest.new()
	rq.timeout = float(opts.get("timeout", 20.0))
	if test_timeout > 0.0:
		rq.timeout = minf(rq.timeout, test_timeout)
	rq.accept_gzip = bool(opts.get("accept_gzip", true))
	owner.add_child(rq)
	var headers := PackedStringArray(["Accept: application/json",
		"User-Agent: CivCity/%s (Godot %s)" % [ProjectSettings.get_setting("application/config/version", ""), Engine.get_version_info().get("string", "")]])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var raw := PackedByteArray()
	if body != null:
		raw = JSON.stringify(body).to_utf8_buffer()
		headers.append("Content-Type: application/json")
		if bool(opts.get("gzip_body", false)):
			raw = raw.compress(FileAccess.COMPRESSION_GZIP)
			headers.append("Content-Encoding: gzip")
	var err := rq.request_raw(api + path, headers, method, raw)
	if err != OK:
		rq.queue_free()
		return _fail(api, method, path, "local:" + error_string(err), t0, true)
	var res: Array = await rq.request_completed
	rq.queue_free()
	var rc := int(res[0])
	if rc != HTTPRequest.RESULT_SUCCESS:
		return _fail(api, method, path, kind_of(rc), t0, rc in [HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR])
	var bytes: PackedByteArray = res[3]
	var d = JSON.parse_string(bytes.get_string_from_utf8()) if bytes.size() > 0 else {}
	if typeof(d) != TYPE_DICTIONARY:
		d = {}
	var code := int(res[1])
	var e := ""
	if code != 200:
		e = str(d.get("error", ""))
		if e == "":
			e = explain({"status": code})["text"] if code in [502, 503, 504] else "Сервер не ответил, попробуйте позже"
		if code >= 500:
			push_warning("NET %s %s → %d (%d ms)" % [_mname(method), path, code, Time.get_ticks_msec() - t0])
	return {"status": code, "data": d, "error": e, "net": "", "ms": Time.get_ticks_msec() - t0, "host": host_of(api), "at": _clock()}


static func _fail(api: String, method: int, path: String, kind: String, t0: int, unsent: bool) -> Dictionary:
	var ms := Time.get_ticks_msec() - t0
	push_warning("NET %s %s → %s (%d ms)" % [_mname(method), path, kind, ms])
	var r := {"status": 0, "data": {}, "net": kind, "ms": ms, "unsent": unsent, "host": host_of(api), "at": _clock()}
	r["error"] = explain(r, "Сервер CivCity", "попробуйте ещё раз")["text"]
	return r


## Код сбоя HTTPRequest → вид причины
static func kind_of(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "dns"
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_NO_RESPONSE, HTTPRequest.RESULT_REQUEST_FAILED:
			return "connect"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "tls"
		HTTPRequest.RESULT_TIMEOUT:
			return "timeout"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED, HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH, HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED, \
				HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "read"
	return "connect"


## Понятная причина для окна: {title, text, short, code}. who — кто не отвечает («Сервер боёв»),
## again — что делать дальше («нажмите «Повторить»», если в окне есть такая кнопка). Никогда не «проверьте интернет»:
## браузер у игрока работает, и такая фраза только путает.
static func explain(r: Dictionary, who := "Сервер CivCity", again := "попробуйте ещё раз") -> Dictionary:
	var st := int(r.get("status", 0))
	var k := String(r.get("net", ""))
	var host := String(r.get("host", "civcity.ru"))
	var out := {"code": code_line(r)}
	if st in [502, 503, 504]:
		out["title"] = "Сервер CivCity ненадолго недоступен"
		out["text"] = "Сервер CivCity сейчас недоступен — скорее всего, идёт обновление. Загляните через пару минут: ваш город в безопасности и сохраняется на этом компьютере."
		out["short"] = "Сервер CivCity обновляется — загляните через пару минут."
	elif st != 0:
		var e := str(r.get("error", "")).strip_edges()
		out["title"] = "Сервер ответил отказом"
		out["text"] = e if e == "" or e.ends_with(".") or e.ends_with("!") or e.ends_with("?") else e + "."
		out["short"] = out["text"]
	elif k == "tls":
		out["title"] = "Защищённое соединение не установилось"
		out["text"] = "Не удалось установить защищённое соединение с сервером. Чаще всего мешают VPN, антивирус с проверкой HTTPS или старые сертификаты Windows. Попробуйте без VPN или обновите Windows."
		out["short"] = "Не удалось установить защищённое соединение — чаще всего мешает VPN или антивирус."
	elif k == "read":
		out["title"] = "Ответ сервера не прочитался"
		out["text"] = "Сервер ответил, но игра не смогла прочитать ответ. Обновите игру через лаунчер; если не поможет — напишите нам, код: read."
		out["short"] = "Сервер ответил, но игра не смогла прочитать ответ (код: read)."
	else:
		out["title"] = ("%s долго не отвечает" if k == "timeout" else "%s не отвечает") % who
		out["text"] = "Игра не смогла связаться с %s. Если включён VPN или прокси — выключите его или добавьте CivCity в исключения и %s. Город, походы и сохранения на компьютере работают и без связи." % [host, again]
		out["short"] = "%s не отвечает. Если включён VPN или прокси — добавьте CivCity в исключения." % who
	return out


## «Код: timeout · 14:32» — мелкая строка под ошибкой (по ней игрок и мы поймём, что случилось)
static func code_line(r: Dictionary) -> String:
	var st := int(r.get("status", 0))
	var c := String(r.get("net", "")) if st == 0 else str(st)
	if c == "":
		return ""
	var at := String(r.get("at", ""))
	return "Код: %s%s" % [c, (" · " + at) if at != "" else ""]


## Имя сервера из адреса api: https://civcity.ru/api → civcity.ru
static func host_of(url: String) -> String:
	var s := url
	var i := s.find("://")
	if i >= 0:
		s = s.substr(i + 3)
	s = s.get_slice("/", 0)
	if s.begins_with("["):
		return s.substr(1, maxi(0, s.find("]") - 1))
	return s.get_slice(":", 0)


static func _mname(method: int) -> String:
	return METHODS[method] if method >= 0 and method < METHODS.size() else str(method)


static func _clock() -> String:
	return Time.get_time_string_from_system().substr(0, 5)
