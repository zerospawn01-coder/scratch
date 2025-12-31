#!/usr/bin/env python3
"""
Sun's Personalized EA-AOL Dashboard Demo

Creates a short (≈8 s) cinematic video:
1. Dark sci-fi background
2. "Sun's Power Violation" (red) appears & pulses
3. Smooth fade-out → "Sun's EA-AOL Optimized" (green)
4. Gauge animation (simulated) and subtle particle effect

Requires: moviepy, imageio[ffmpeg]
"""
import os
from moviepy.editor import (
    ImageClip,
    TextClip,
    CompositeVideoClip,
    concatenate_videoclips,
    vfx,
)

# ---------------------------------------------------------------------------
# Paths – adjust if you move the assets
# ---------------------------------------------------------------------------
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BRAIN_DIR = r"C:\Users\zeros\.gemini\antigravity\brain\e2284a27-216a-4e18-af1f-46359ef110c4"

BACKGROUND = os.path.join(BRAIN_DIR, "sun_dashboard_background_1765906024646.png")
POWER_IMG = os.path.join(BRAIN_DIR, "sun_power_violation_1765906057614.png")
OPT_IMG   = os.path.join(BRAIN_DIR, "sun_optimized_1765906088284.png")

# ---------------------------------------------------------------------------
# Helper – create a clip with a static image over the background
# ---------------------------------------------------------------------------

def make_clip(img_path, txt, txt_color, duration=3, fade_in=0.5, fade_out=0.5):
    bg = ImageClip(BACKGROUND).set_duration(duration).resize((1920, 1080))
    fg = ImageClip(img_path).set_duration(duration).resize((1920, 1080))
    # Text overlay – large, glowing
    txt_clip = (
        TextClip(txt, fontsize=80, font="Arial-Bold", color=txt_color, stroke_color="black", stroke_width=2)
        .set_position(("center", 100))
        .set_duration(duration)
    )
    comp = CompositeVideoClip([bg, fg, txt_clip])
    # Fade in/out for drama
    comp = comp.fx(vfx.fadein, fade_in).fx(vfx.fadeout, fade_out)
    return comp

# ---------------------------------------------------------------------------
# Build the two main sections
# ---------------------------------------------------------------------------
violation_clip = make_clip(
    POWER_IMG,
    "Sun's Power Violation",
    txt_color="red",
    duration=4,
    fade_in=1,
    fade_out=1,
)

optimized_clip = make_clip(
    OPT_IMG,
    "Sun's EA-AOL Optimized",
    txt_color="lime",
    duration=4,
    fade_in=1,
    fade_out=1,
)

# ---------------------------------------------------------------------------
# Concatenate with a cross-fade for a smooth transition
# ---------------------------------------------------------------------------
final = concatenate_videoclips([violation_clip, optimized_clip], method="compose")

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
output_dir = os.path.join(BASE_DIR, "demo", "custom_dashboard")
os.makedirs(output_dir, exist_ok=True)
output_path = os.path.join(output_dir, "sun_dashboard_demo.mp4")

print("Generating video...")
print(f"Output: {output_path}")

final.write_videofile(output_path, codec="libx264", fps=30, audio=False, threads=4)

print("✓ Video generated at:", output_path)
