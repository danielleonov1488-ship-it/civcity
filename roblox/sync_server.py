# Живая синхронизация кода в открытый Roblox Studio (без пересборки места).
# Отдаёт на http://127.0.0.1:34873/all все скрипты из src/ одним JSON:
#   [{"path": ["ServerScriptService", "Main"], "class": "Script", "source": "..."}, ...]
# Studio забирает их кодом из roblox/sync.luau (выполнить через MCP execute_luau в режиме Edit;
# в месте должно быть включено HttpService.HttpEnabled — sync.luau включает его сам).
# Запуск: python -I sync_server.py
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'src')
PORT = 34873
SUFFIXES = (('.server.luau', 'Script'), ('.client.luau', 'LocalScript'), ('.luau', 'ModuleScript'))


def collect():
    out = []
    for dirpath, _, files in os.walk(SRC):
        rel = os.path.relpath(dirpath, SRC)
        folders = [] if rel == '.' else rel.split(os.sep)
        for name in sorted(files):
            for suffix, cls in SUFFIXES:
                if name.endswith(suffix):
                    with open(os.path.join(dirpath, name), encoding='utf-8') as f:
                        out.append({'path': folders + [name[:-len(suffix)]], 'class': cls, 'source': f.read()})
                    break
    return out


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != '/all':
            self.send_error(404)
            return
        body = json.dumps(collect(), ensure_ascii=False).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    print(f'sync: http://127.0.0.1:{PORT}/all <- {SRC}')
    ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
