# Приёмник кадров для съёмки ролика CivCity (только localhost).
#   POST /raw?shot=имя&w=2560&h=1440&fps=30 — сырой кадр RGBA (снизу вверх, как отдаёт WebGL) уходит прямо в ffmpeg
#   POST /end?shot=имя — закончить клип: ffmpeg дописывает D:\CivCity\promo\shots\<имя>.mp4
#   POST /frame?shot=имя&i=номер — одиночный JPEG для проверки в D:\CivCity\promo\frames\<имя>\
import os
import re
import shutil
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

ROOT = r'D:\CivCity\promo'
FFMPEG = shutil.which('ffmpeg') or 'ffmpeg'
procs = {}
lock = threading.Lock()


def start(shot, w, h, fps):
    os.makedirs(os.path.join(ROOT, 'shots'), exist_ok=True)
    out = os.path.join(ROOT, 'shots', shot + '.mp4')
    cmd = [FFMPEG, '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', f'{w}x{h}', '-r', str(fps), '-i', '-',
           '-vf', 'vflip', '-c:v', 'libx264', '-preset', 'medium', '-crf', '15', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out]
    return subprocess.Popen(cmd, stdin=subprocess.PIPE)


class H(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def _ok(self, code=200, body=b''):
        self.send_response(code); self._cors(); self.end_headers()
        if body: self.wfile.write(body)

    def do_OPTIONS(self):
        self._ok(204)

    def do_POST(self):
        u = urlparse(self.path)
        q = {k: v[0] for k, v in parse_qs(u.query).items()}
        shot = q.get('shot', '')
        if not re.fullmatch(r'[a-z0-9_-]{1,40}', shot):
            return self._ok(400)
        n = int(self.headers.get('Content-Length', 0))
        data = self.rfile.read(n) if n else b''
        if u.path == '/raw':
            with lock:
                p = procs.get(shot)
                if p is None:
                    p = procs[shot] = start(shot, int(q['w']), int(q['h']), int(q.get('fps', 30)))
                p.stdin.write(data)
            return self._ok()
        if u.path == '/end':
            with lock:
                p = procs.pop(shot, None)
            if p:
                p.stdin.close()
                p.wait()
            return self._ok(body=b'done')
        if u.path == '/frame' and q.get('i', '').isdigit():
            d = os.path.join(ROOT, 'frames', shot)
            os.makedirs(d, exist_ok=True)
            with open(os.path.join(d, 'f_%05d.jpg' % int(q['i'])), 'wb') as f:
                f.write(data)
            return self._ok()
        self._ok(404)

    def log_message(self, *a):
        pass


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5192
    ThreadingHTTPServer(('127.0.0.1', port), H).serve_forever()
