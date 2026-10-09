# Локальный сервер игры для ярлыков .bat: как python -m http.server, но просит браузер
# сверять файлы с диском (no-cache), чтобы после обновления игры не грузился старый код.
import http.server
import os
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()


os.chdir(os.path.dirname(os.path.abspath(__file__)))
port = int(sys.argv[1]) if len(sys.argv) > 1 else 5181
http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler).serve_forever()
