# ===== addons/AI_Yandex/http_server.gd =====
@tool
extends Node

signal code_received(code: String, file_path: String)

var tcp_server: TCPServer = null
var port: int = 9876
var is_running: bool = false
var _clients: Array[Dictionary] = []
var _buffers: Dictionary = {}

func start(server_port: int = 9876) -> Error:
if is_running:
push_warning("[AI_Yandex] HTTP server already running")
return OK

port = server_port
tcp_server = TCPServer.new()
var err: Error = tcp_server.listen(port, "127.0.0.1")
if err != OK:
push_error("[AI_Yandex] Failed to start HTTP server on port %d: %s" % [port, error_string(err)])
tcp_server = null
return err

is_running = true
print("[AI_Yandex] HTTP server started on 127.0.0.1:%d" % port)
return OK

func stop() -> void:
for c in _clients:
var peer: StreamPeerTCP = c.get("peer", null)
if peer != null:
peer.disconnect_from_host()
_clients.clear()
_buffers.clear()
if tcp_server != null:
tcp_server.stop()
tcp_server = null
is_running = false
print("[AI_Yandex] HTTP server stopped")

func _exit_tree() -> void:
stop()

func _process(_delta: float) -> void:
if not is_running or tcp_server == null:
return

# Принимаем новые подключения
while tcp_server.is_connection_available():
var peer := tcp_server.take_connection()
if peer != null:
_clients.append({"peer": peer, "buf": PackedByteArray(), "deadline": Time.get_ticks_msec() + 5000})

# Читаем из существующих клиентов
var still_alive: Array[Dictionary] = []
for c in _clients:
var peer: StreamPeerTCP = c["peer"]
peer.poll()
var status: int = peer.get_status()

if status != StreamPeerTCP.STATUS_CONNECTED:
if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
continue

var avail: int = peer.get_available_bytes()
if avail > 0:
var data = peer.get_data(avail)
if data[0] == OK and data[1].size() > 0:
var buf: PackedByteArray = c["buf"]
buf.append_array(data[1])
c["buf"] = buf

var buf2: PackedByteArray = c["buf"]
var text: String = buf2.get_string_from_utf8()
var header_end: int = text.find("\r\n\r\n")
if header_end != -1:
_handle_request(peer, text)
c["buf"] = PackedByteArray()
continue

if Time.get_ticks_msec() > int(c["deadline"]):
peer.disconnect_from_host()
continue

still_alive.append(c)

_clients = still_alive

func _handle_request(peer: StreamPeerTCP, raw: String) -> void:
var header_end: int = raw.find("\r\n\r\n")
if header_end == -1:
return

var head: String = raw.substr(0, header_end)
var body: String = raw.substr(header_end + 4)
var lines: PackedStringArray = head.split("\r\n")
if lines.is_empty():
_send(peer, 400, {"error": "bad request"})
return

var request_line: PackedStringArray = lines[0].split(" ")
if request_line.size() < 2:
_send(peer, 400, {"error": "bad request line"})
return

var method: String = request_line[0]
var path: String = request_line[1]

if method == "GET" and path == "/health":
_send(peer, 200, {"status": "ok", "port": port})
return

if method == "POST" and path == "/execute":
var parsed: Variant = JSON.parse_string(body)
if typeof(parsed) != TYPE_DICTIONARY:
_send(peer, 400, {"error": "invalid json"})
return
var d: Dictionary = parsed
var code: String = str(d.get("code", ""))
var file_path: String = str(d.get("file_path", ""))
code_received.emit(code, file_path)
_send(peer, 200, {"status": "queued", "len": code.length()})
return

_send(peer, 404, {"error": "not found"})

func _send(peer: StreamPeerTCP, code: int, payload: Dictionary) -> void:
var body: String = JSON.stringify(payload)
var reason: String = "OK" if code == 200 else ("Bad Request" if code == 400 else "Not Found")
var resp: String = "HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [code, reason, body.length(), body]
var bytes: PackedByteArray = resp.to_utf8_buffer()
peer.put_data(bytes)
peer.disconnect_from_host()
