"""Аудио «было → стало» для владельца: старый звук, пауза, новые. python -I hf_preview.py <battle_dir> <out.mp3>"""
import subprocess, sys, os
import numpy as np
FF = "C:/Users/danze/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-8.1.2-full_build/bin/ffmpeg"
SR = 44100
d, out = sys.argv[1], sys.argv[2]
def ld(n):
    raw = subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-i", os.path.join(d, n + ".ogg"), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)
def gap(s): return np.zeros(int(s * SR))
def mix(a, b, gb=1.0):
    n = max(len(a), len(b)); o = np.zeros(n); o[:len(a)] += a; o[:len(b)] += b * gb; return o
groups = [
    (["knifeSlice"], ["hf_clash1", "hf_clash2", "hf_clash3"]),
    (["cloth1"], ["hf_volley"]),
    (["dropLeather"], ["hf_boom"]),
    (["metalPot1"], [("metalPot1", "hf_oil")]),
    ([], ["hf_cry"]),
]
seq = [gap(0.4)]
for old, new in groups:
    for o in old:
        seq += [ld(o) * 0.8, gap(0.9)]
    for n in new:
        x = mix(ld(n[0]) * 0.8, ld(n[1]), 0.7) if isinstance(n, tuple) else ld(n)
        seq += [x, gap(0.45)]
    seq.append(gap(1.1))
y = np.concatenate(seq)
y *= 0.89 / max(1e-9, np.abs(y).max())
subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-c:a", "libmp3lame", "-q:a", "2", out],
    input=y.astype(np.float32).tobytes(), check=True)
print("ok", round(len(y) / SR, 1), "s ->", out)
