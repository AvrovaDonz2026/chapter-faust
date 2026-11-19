#!/usr/bin/env python3
from pathlib import Path
import shutil, subprocess, sys
out=Path(__file__).parents[1]/'audio/episode-001-music.wav'; out.parent.mkdir(exist_ok=True)
ff=shutil.which('ffmpeg')
if not ff: print('FFmpeg unavailable; music generation skipped', file=sys.stderr); raise SystemExit(2)
# Layered low tones: deterministic, license-free placeholder music bed.
cmd=[ff,'-y','-f','lavfi','-i','sine=frequency=110:duration=30','-f','lavfi','-i','sine=frequency=220:duration=30','-filter_complex','[0:a]volume=0.12[a];[1:a]volume=0.05[b];[a][b]amix=inputs=2:duration=longest,afade=t=in:st=0:d=2,afade=t=out:st=26:d=4','-ar','48000','-ac','2',str(out)]
subprocess.run(cmd,check=True); print(out)
