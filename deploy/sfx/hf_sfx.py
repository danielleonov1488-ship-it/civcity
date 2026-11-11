"""Нарезка и выравнивание громкости звуков боя из Higgsfield (Mirelo) -> ogg для Godot.
Запуск: python -I hf_sfx.py <папка_mp3> <папка_вывода>"""
import subprocess, sys, os
import numpy as np

FF = "/c/Users/danze/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-8.1.2-full_build/bin/ffmpeg"
FF = FF.replace("/c/", "C:/", 1)
SR = 44100
src, out = sys.argv[1], sys.argv[2]

# имя: (файл, начало, конец, нарастание, затухание, режим, цель_дБ)
# режим "peak" — пик к цели; "rms" — средняя громкость к цели (для ровного шума вроде шипения)
CLIPS = {
	"hf_clash1": ("9_sword_shield2", 0.285, 0.64, 0.004, 0.14, "peak", -1.0),
	"hf_clash2": ("9_sword_shield2", 0.685, 1.02, 0.004, 0.14, "peak", -1.0),
	"hf_clash3": ("9_sword_shield2", 0.135, 0.28, 0.004, 0.06, "peak", -1.0),
	"hf_boom": ("7_catapult", 0.57, 2.02, 0.003, 0.55, "peak", -1.0),
	"hf_volley": ("3_arrows_volley", 0.38, 1.75, 0.05, 0.45, "peak", -1.0),
	"hf_oil": ("8_oil_sizzle", 0.0, 1.6, 0.08, 0.5, "rms", -19.0),
	"hf_cry": ("6_battle_cry", 0.0, 2.0, 0.1, 0.6, "peak", -1.0),
}


def load(name):
	raw = subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-i", os.path.join(src, name + ".mp3"),
		"-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True).stdout
	return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


os.makedirs(out, exist_ok=True)
cache = {}
for nm, (f, a, b, fi, fo, mode, tgt) in CLIPS.items():
	if f not in cache:
		cache[f] = load(f)
	x = cache[f][int(a * SR):int(b * SR)].copy()
	x -= x.mean()
	n_in, n_out = max(1, int(fi * SR)), max(1, int(fo * SR))
	x[:n_in] *= np.linspace(0.0, 1.0, n_in)
	x[-n_out:] *= np.linspace(1.0, 0.0, n_out) ** 2
	if mode == "peak":
		g = 10 ** (tgt / 20) / max(1e-9, np.abs(x).max())
	else:
		g = 10 ** (tgt / 20) / max(1e-9, np.sqrt(np.mean(x ** 2)))
		g = min(g, 10 ** (-1 / 20) / max(1e-9, np.abs(x).max()))
	x *= g
	pcm = np.clip(x, -1, 1).astype(np.float32).tobytes()
	dst = os.path.join(out, nm + ".ogg")
	subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
		"-c:a", "libvorbis", "-q:a", "6", dst], input=pcm, check=True)
	rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
	print("%-10s %.2fs gain %+.1f dB rms %.1f dBFS -> %s" % (nm, len(x) / SR, 20 * np.log10(g), rms, dst))
