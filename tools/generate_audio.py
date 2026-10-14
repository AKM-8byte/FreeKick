"""Original procedural effects; no external recordings or dependencies."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
OUT.mkdir(parents=True, exist_ok=True)

def create(name, duration, kind, seed):
    rng = random.Random(seed)
    samples = []
    low = 0.0
    for i in range(int(duration * RATE)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low = low * 0.92 + noise * 0.08
        if kind == 'step':
            v = (low * 1.4 + noise * 0.18) * math.exp(-t * 24) + math.sin(2*math.pi*95*t)*math.exp(-t*40)*0.22
        elif kind in ('kick', 'bounce'):
            decay = 22 if kind == 'kick' else 32
            v = math.sin(2*math.pi*(105*t - 80*t*t)) * math.exp(-t*decay)*0.72 + noise*math.exp(-t*65)*0.24
        elif kind == 'post':
            v = sum(math.sin(2*math.pi*f*t)*math.exp(-t*d)*a for f,d,a in [(420,5,.3),(1137,9,.22),(1783,14,.12)]) + noise*math.exp(-t*90)*.1
        elif kind == 'net':
            v = (noise*.22 + low*.6)*math.exp(-t*9)*(0.7+0.3*math.sin(t*91)**2)
        elif kind == 'goal':
            env = min(1,t*5)*min(1,(duration-t)*1.6)
            voices = sum(math.sin(2*math.pi*(f*t + .7*math.sin(t*k)))*.035 for f,k in [(163,2.1),(209,1.8),(271,2.8),(341,1.3),(397,2.4),(489,1.7)])
            v = (low*.7 + noise*.1 + voices)*env*(.85+.15*math.sin(t*4))
        else:
            # A continuous, seamlessly enveloped distant crowd bed.
            env = math.sin(math.pi*t/duration)**2
            v = (low*.7 + math.sin(t*1303)*.015)*env
        samples.append(v * min(1, t * 800))
    peak = max(abs(v) for v in samples) or 1
    pcm = b''.join(struct.pack('<h', int(max(-1,min(1,v/peak*.82))*32767)) for v in samples)
    with wave.open(str(OUT / (name + '.wav')), 'wb') as file:
        file.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        file.writeframes(pcm)

for index,(name,duration) in enumerate([('step',.24),('kick',.32),('bounce',.24),('post',.85),('net',.65),('goal',2.5),('ambience',12)]):
    create(name,duration,name,index+931)
print('Generated 7 original WAV files in assets/audio')
