"""Original synthesized biscuit flip: airy swish with dry crumb clicks.
Run with Python 3; no dependencies. Output: 48 kHz mono PCM WAV.
"""
from pathlib import Path
import math
import random
import struct
import wave

rate = 48000
length = 0.24
rng = random.Random(271926)
clicks = [(0.012, 0.35, 0.010), (0.028, 0.20, 0.007),
          (0.075, 0.12, 0.012), (0.133, 0.27, 0.014),
          (0.151, 0.18, 0.010), (0.180, 0.08, 0.012)]
samples = []
low = previous = 0.0
for i in range(round(rate * length)):
    t = i / rate
    noise = rng.uniform(-1, 1)
    low += 0.17 * (noise - low)
    airy = low - previous
    previous = low
    envelope = math.sin(math.pi * t / length) ** 2
    value = airy * 0.65 * envelope
    for onset, gain, decay in clicks:
        dt = t - onset
        if dt >= 0:
            attack = min(1, dt / 0.001)
            value += gain * attack * math.exp(-dt / decay) * (
                noise * 0.65 + math.sin(2 * math.pi * 1450 * dt) * 0.20
                + math.sin(2 * math.pi * 2300 * dt) * 0.15)
    # Soft low body, rather than a loud impact or cartoon whistle.
    value += 0.12 * math.sin(2 * math.pi * (190 * t - 130 * t * t)) * math.exp(-t * 24) * min(1, t / 0.004)
    value *= min(1, (length - t) / 0.02)
    samples.append(value)
peak = max(abs(x) for x in samples)
with wave.open(str(Path(__file__).with_name('butterkek_flip.wav')), 'wb') as out:
    out.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    out.writeframes(b''.join(struct.pack('<h', round(x / peak * 0.65 * 32767)) for x in samples))
