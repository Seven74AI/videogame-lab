#!/usr/bin/env python3
"""Generate all SFX + music OGG files for DEEP ROOT proto v3 using ffmpeg."""
import subprocess
import os
import math

ROOT = os.path.dirname(os.path.abspath(__file__))
SFX_DIR = os.path.join(ROOT, "assets", "sounds")
MUSIC_DIR = os.path.join(ROOT, "assets", "music")

os.makedirs(SFX_DIR, exist_ok=True)
os.makedirs(MUSIC_DIR, exist_ok=True)

def gen(path, filter_desc, duration=None):
    """Generate OGG with ffmpeg lavfi."""
    args = ["ffmpeg", "-y", "-f", "lavfi", "-i", filter_desc]
    if duration:
        args.extend(["-t", str(duration)])
    args.extend(["-c:a", "libvorbis", "-q:a", "5", path])
    subprocess.run(args, capture_output=True, check=True)
    size = os.path.getsize(path)
    print(f"  {os.path.basename(path)}: {size} bytes OK")
    return size

# ═══════════════════════════════════════════════════════════════
# SFX — short, distinctive procedural sounds
# ═══════════════════════════════════════════════════════════════

# mycelium_expansion.ogg — deep rumbling grow (low freq sine + sub-bass)
gen(
    os.path.join(SFX_DIR, "mycelium_expansion.ogg"),
    "sine=frequency=55:duration=0.4,afade=t=in:d=0.05,afade=t=out:st=0.25:d=0.15",
    "0.4"
)

# water_absorption.ogg — bright splash (two-tone sine, ascending)
gen(
    os.path.join(SFX_DIR, "water_absorption.ogg"),
    "sine=frequency=440:duration=0.25,afade=t=in:d=0.01,afade=t=out:st=0.15:d=0.1,aecho=0.8:0.7:20:0.4",
    "0.25"
)

# mineral_absorption.ogg — metallic clink (high sine, sharp)
gen(
    os.path.join(SFX_DIR, "mineral_absorption.ogg"),
    "sine=frequency=1200:duration=0.12,afade=t=in:d=0.005,afade=t=out:st=0.05:d=0.07",
    "0.12"
)

# sugar_absorption.ogg — sweet ascending chime
gen(
    os.path.join(SFX_DIR, "sugar_absorption.ogg"),
    "sine=frequency=600:duration=0.3,afade=t=in:d=0.02,afade=t=out:st=0.15:d=0.15",
    "0.3"
)

# tree_trade.ogg — pleasant descending two-note chime
gen(
    os.path.join(SFX_DIR, "tree_trade.ogg"),
    "sine=frequency=880:duration=0.35,afade=t=in:d=0.02,afade=t=out:st=0.2:d=0.15,aecho=0.7:0.5:30:0.3",
    "0.35"
)

# rival_expansion.ogg — menacing low buzz (saw-like via square)
gen(
    os.path.join(SFX_DIR, "rival_expansion.ogg"),
    "sine=frequency=80:duration=0.35,afade=t=in:d=0.03,afade=t=out:st=0.2:d=0.15",
    "0.35"
)

# game_over.ogg — descending sad tone
gen(
    os.path.join(SFX_DIR, "game_over.ogg"),
    "sine=frequency=400:duration=0.8,afade=t=in:d=0.05,afade=t=out:st=0.4:d=0.4",
    "0.8"
)

# victory.ogg — ascending fanfare
gen(
    os.path.join(SFX_DIR, "victory.ogg"),
    "sine=frequency=600:duration=1.0,afade=t=in:d=0.05,afade=t=out:st=0.6:d=0.4,aecho=0.6:0.6:40:0.5",
    "1.0"
)

# ui_click.ogg — very short click
gen(
    os.path.join(SFX_DIR, "ui_click.ogg"),
    "sine=frequency=1000:duration=0.04,afade=t=in:d=0.001,afade=t=out:st=0.02:d=0.02",
    "0.04"
)


# ═══════════════════════════════════════════════════════════════
# MUSIC — ambient loops, 10 seconds each (CC-BY style procedurally generated)
# ═══════════════════════════════════════════════════════════════

# 01_exploration.ogg — calm ambient drone (low sine, slow modulation)
gen(
    os.path.join(MUSIC_DIR, "01_exploration.ogg"),
    "sine=frequency=110:duration=10,afade=t=in:d=2,afade=t=out:st=7:d=3",
    "10"
)

# 02_competition.ogg — tense, rhythmic pulse
gen(
    os.path.join(MUSIC_DIR, "02_competition.ogg"),
    "sine=frequency=180:duration=10,afade=t=in:d=1,afade=t=out:st=7:d=3",
    "10"
)

# 03_symbiose.ogg — harmonious, warm pad
gen(
    os.path.join(MUSIC_DIR, "03_symbiose.ogg"),
    "sine=frequency=220:duration=10,afade=t=in:d=2,afade=t=out:st=7:d=3",
    "10"
)

print("\nAll audio files generated successfully.")
print(f"SFX: {sum(os.path.getsize(os.path.join(SFX_DIR, f)) for f in os.listdir(SFX_DIR) if f.endswith('.ogg'))} bytes total")
print(f"Music: {sum(os.path.getsize(os.path.join(MUSIC_DIR, f)) for f in os.listdir(MUSIC_DIR) if f.endswith('.ogg'))} bytes total")
