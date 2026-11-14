#!/usr/bin/env python3
"""Renders the sound effects of the web version of Bút Chiến to WAV files.

The web game synthesised every sound with WebAudio (oscillators with exponential
ramps and band-passed noise). This script reproduces the same recipes offline so
the Flutter app can play them as assets. Run: python3 tool/gen-sfx.py
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
GAIN = 1.8  # mobile speakers are quieter than desktop ones


def _osc(kind, phase, freq):
    """Band-limited oscillator sample at the given phase (radians)."""
    if kind == 'sine':
        return math.sin(phase)
    limit = min(12000, SR / 2 - 200)
    total = 0.0
    k = 1
    while k * freq < limit and k < 40:
        if kind == 'square':
            total += math.sin(k * phase) / k
        else:  # triangle
            sign = -1 if (k // 2) % 2 else 1
            total += sign * math.sin(k * phase) / (k * k)
        k += 2
    return total * (4 / math.pi if kind == 'square' else 8 / (math.pi * math.pi))


def tone(buf, t0, f, dur, kind='sine', vol=0.15, slide=None):
    """OscillatorNode with exponential gain decay to 0.0001 and optional frequency slide."""
    f1 = max(40.0, f * slide) if slide else f
    n = int((dur + 0.05) * SR)
    start = int(t0 * SR)
    phase = 0.0
    for i in range(n):
        t = i / SR
        u = min(1.0, t / dur)
        freq = f * (f1 / f) ** u
        gain = vol * (0.0001 / vol) ** u
        phase += 2 * math.pi * freq / SR
        j = start + i
        if j < len(buf):
            buf[j] += _osc(kind, phase, freq) * gain


def hiss(buf, t0, dur, vol, freq, q=1.0, seed=1):
    """White noise through a WebAudio-style band-pass biquad, with exponential decay."""
    rnd = random.Random(seed)
    w0 = 2 * math.pi * freq / SR
    alpha = math.sin(w0) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w0), 1 - alpha
    x1 = x2 = y1 = y2 = 0.0
    n = int((dur + 0.05) * SR)
    start = int(t0 * SR)
    for i in range(n):
        x = rnd.uniform(-1, 1)
        y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, x, y1, y
        u = min(1.0, (i / SR) / dur)
        gain = vol * (0.0001 / vol) ** u
        j = start + i
        if j < len(buf):
            buf[j] += y * gain


def render(name, length, *voices):
    buf = [0.0] * int(length * SR)
    for v in voices:
        v(buf)
    path = os.path.join(OUT, name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in buf:
            s = math.tanh(s * GAIN)
            frames += struct.pack('<h', int(max(-1.0, min(1.0, s)) * 32000))
        w.writeframes(bytes(frames))
    return path


def T(t0, *a, **k):
    return lambda b: tone(b, t0, *a, **k)


def H(t0, *a, **k):
    return lambda b: hiss(b, t0, *a, **k)


def main():
    os.makedirs(OUT, exist_ok=True)
    sounds = {
        # Original recipes from the web game.
        'whoosh': (0.25, [H(0, 0.16, 0.1, 700, 0.8)]),
        'hit': (0.3, [T(0, 150, 0.2, 'triangle', 0.28, 0.45), H(0, 0.07, 0.18, 2200, 1)]),
        'block': (0.2, [T(0, 620, 0.1, 'square', 0.05, 0.7), H(0, 0.05, 0.1, 3200, 2)]),
        'parry': (0.4, [T(0, 990, 0.22, 'triangle', 0.16, 1.4), T(0, 1480, 0.3, 'sine', 0.08)]),
        'fall': (0.8, [T(0, 520, 0.7, 'sine', 0.12, 0.2)]),
        'coin': (0.3, [T(0, 1320, 0.08, 'square', 0.05), T(0.07, 1760, 0.14, 'square', 0.05)]),
        'lvup': (0.5, [T(i * 0.09, f, 0.16, 'triangle', 0.12) for i, f in enumerate([523, 659, 784, 1047])]),
        'win': (0.5, [T(i * 0.11, f, 0.18, 'triangle', 0.12) for i, f in enumerate([523, 659, 784])]),
        'lose': (0.7, [T(i * 0.14, f, 0.22, 'triangle', 0.1) for i, f in enumerate([392, 330, 262])]),
        # New sounds in the same style.
        'tap': (0.1, [T(0, 880, 0.05, 'sine', 0.06, 1.2)]),
        'buy': (0.35, [T(0, 1046, 0.08, 'square', 0.05), T(0.06, 1318, 0.08, 'square', 0.05), T(0.12, 1568, 0.16, 'square', 0.05)]),
        'star': (0.4, [T(0, 1568, 0.12, 'triangle', 0.1), T(0.08, 2093, 0.25, 'sine', 0.08)]),
        'freeze': (0.4, [H(0, 0.3, 0.08, 5000, 3, seed=2), T(0, 1800, 0.25, 'sine', 0.04, 0.6)]),
        'burn': (0.45, [H(0, 0.35, 0.1, 900, 0.6, seed=3), T(0, 220, 0.3, 'triangle', 0.05, 0.7)]),
        'zap': (0.25, [T(0, 1200, 0.12, 'square', 0.05, 0.3), H(0, 0.1, 0.1, 4000, 1.5, seed=4)]),
        'heal': (0.4, [T(0, 660, 0.18, 'sine', 0.08, 1.5), T(0.08, 990, 0.2, 'sine', 0.06, 1.3)]),
        'crumble': (0.6, [H(0, 0.5, 0.12, 300, 0.7, seed=5), T(0, 90, 0.5, 'triangle', 0.12, 0.6)]),
    }
    for name, (length, voices) in sounds.items():
        print(render(name, length, *voices))


if __name__ == '__main__':
    main()
