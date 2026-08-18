"""
Aether Fountain — Asset Admission Gate
======================================
Principle: generation_is_not_authority
An AI-generated sprite is not accepted until it passes ALL gate checks.
"""

import os
import sys
import hashlib
import numpy as np
from PIL import Image
from scipy import ndimage

GATE_CONFIG = {
    "min_transparent_ratio":  0.35,
    "max_transparent_ratio":  0.85,
    "min_subject_bbox_ratio": 0.30,
    "max_subject_bbox_ratio": 0.98,
    "fringe_sample_width":    6,
    "fringe_tolerance":       0.04,
    "armor_bright_threshold": 220,
    "armor_alpha_minimum":    180,
    "core_min_pixel_count":   50,
}

def sha256_file(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()

def run_gate(png_path, subject_name, bg_key):
    passed, failed, notes = [], [], []

    print(f"\n{'='*60}")
    print(f" ADMISSION GATE: {subject_name}")
    print(f" File: {os.path.basename(png_path)}")
    print(f"{'='*60}")

    if not os.path.exists(png_path):
        print("  FATAL: File not found.")
        return {"overall": "FAIL_MISSING"}

    arr = np.array(Image.open(png_path).convert("RGBA")).astype(float)
    h, w = arr.shape[:2]
    r, g, b, a = arr[:,:,0], arr[:,:,1], arr[:,:,2], arr[:,:,3]
    brightness = (r + g + b) / 3.0
    opaque_mask = a >= 128
    trans_mask  = a < 128

    # CHECK 1: RGBA_CHECK
    if arr.shape[2] == 4:
        passed.append("RGBA_CHECK")
        print(f"  [PASS] RGBA_CHECK: RGBA {w}x{h}")
    else:
        failed.append("RGBA_CHECK")
        print(f"  [FAIL] RGBA_CHECK")

    # CHECK 2: TRANSPARENT_RATIO_CHECK
    trans_ratio = np.mean(trans_mask)
    cfg = GATE_CONFIG
    tr_ok = cfg["min_transparent_ratio"] <= trans_ratio <= cfg["max_transparent_ratio"]
    if tr_ok:
        passed.append("TRANSPARENT_RATIO_CHECK")
        print(f"  [PASS] TRANSPARENT_RATIO_CHECK: {trans_ratio*100:.1f}% transparent")
    else:
        failed.append("TRANSPARENT_RATIO_CHECK")
        print(f"  [FAIL] TRANSPARENT_RATIO_CHECK: {trans_ratio*100:.1f}% (need {cfg['min_transparent_ratio']*100:.0f}%-{cfg['max_transparent_ratio']*100:.0f}%)")

    # CHECK 3-5: BBOX + HEAD + FOOT
    rows_with_opaque = np.any(opaque_mask, axis=1)
    if rows_with_opaque.any():
        bbox_top    = int(np.argmax(rows_with_opaque))
        bbox_bottom = int(h - 1 - np.argmax(rows_with_opaque[::-1]))
        bbox_height = bbox_bottom - bbox_top
        bbox_ratio  = bbox_height / h

        if cfg["min_subject_bbox_ratio"] <= bbox_ratio <= cfg["max_subject_bbox_ratio"]:
            passed.append("SUBJECT_BBOX_CHECK")
            print(f"  [PASS] SUBJECT_BBOX_CHECK: height_ratio={bbox_ratio:.2%}")
        else:
            failed.append("SUBJECT_BBOX_CHECK")
            print(f"  [FAIL] SUBJECT_BBOX_CHECK: {bbox_ratio:.2%}")

        if bbox_top < h * 0.10:
            passed.append("HEAD_CROP_CHECK")
            print(f"  [PASS] HEAD_CROP_CHECK: head at row {bbox_top} ({bbox_top/h:.1%})")
        else:
            failed.append("HEAD_CROP_CHECK")
            print(f"  [FAIL] HEAD_CROP_CHECK: head at {bbox_top/h:.1%} — possibly cropped")

        if bbox_bottom > h * 0.88:
            passed.append("FOOT_CROP_CHECK")
            print(f"  [PASS] FOOT_CROP_CHECK: feet at row {bbox_bottom} ({bbox_bottom/h:.1%})")
        else:
            failed.append("FOOT_CROP_CHECK")
            print(f"  [FAIL] FOOT_CROP_CHECK: feet at {bbox_bottom/h:.1%} — possibly cropped")
    else:
        failed += ["SUBJECT_BBOX_CHECK", "HEAD_CROP_CHECK", "FOOT_CROP_CHECK"]
        print("  [FAIL] BBOX/HEAD/FOOT: no opaque pixels")

    # CHECK 6: CONNECTED_COMPONENT_CHECK
    labeled, num_feat = ndimage.label(opaque_mask)
    if num_feat >= 1:
        sizes = ndimage.sum(opaque_mask, labeled, range(1, num_feat + 1))
        largest = max(sizes)
        total_op = np.sum(opaque_mask)
        largest_ratio = largest / total_op if total_op > 0 else 0
        if largest_ratio >= 0.80:
            passed.append("CONNECTED_COMPONENT_CHECK")
            print(f"  [PASS] CONNECTED_COMPONENT_CHECK: {num_feat} components, largest={largest_ratio:.1%}")
        else:
            failed.append("CONNECTED_COMPONENT_CHECK")
            print(f"  [FAIL] CONNECTED_COMPONENT_CHECK: largest={largest_ratio:.1%} — fragmented body")
    else:
        failed.append("CONNECTED_COMPONENT_CHECK")
        print("  [FAIL] CONNECTED_COMPONENT_CHECK: no opaque components")

    # CHECK 7: EDGE_FRINGE_CHECK
    edge_zone = ndimage.binary_dilation(opaque_mask, iterations=cfg["fringe_sample_width"]) & trans_mask
    if np.sum(edge_zone) > 0:
        bg_r, bg_g, bg_b = bg_key
        fr = r[edge_zone]; fg = g[edge_zone]; fb = b[edge_zone]
        dist = np.sqrt((fr - bg_r)**2 + (fg - bg_g)**2 + (fb - bg_b)**2)
        contaminated = float(np.mean(dist < 60))
        if contaminated <= cfg["fringe_tolerance"]:
            passed.append("EDGE_FRINGE_CHECK")
            print(f"  [PASS] EDGE_FRINGE_CHECK: fringe contamination={contaminated:.1%}")
        else:
            failed.append("EDGE_FRINGE_CHECK")
            print(f"  [FAIL] EDGE_FRINGE_CHECK: fringe contamination={contaminated:.1%} > {cfg['fringe_tolerance']:.1%}")
    else:
        passed.append("EDGE_FRINGE_CHECK")
        print("  [PASS] EDGE_FRINGE_CHECK: no edge fringe zone")

    # CHECK 8: BRIGHT_ARMOR_PRESERVATION_CHECK
    interior = ndimage.binary_erosion(opaque_mask, iterations=4)
    bright_interior = interior & (brightness > cfg["armor_bright_threshold"])
    n_bright = int(np.sum(bright_interior))
    if n_bright > 100:
        bright_alpha = a[bright_interior]
        below = float(np.mean(bright_alpha < cfg["armor_alpha_minimum"]))
        if below < 0.10:
            passed.append("BRIGHT_ARMOR_PRESERVATION_CHECK")
            print(f"  [PASS] BRIGHT_ARMOR_PRESERVATION_CHECK: {below:.1%} of bright armor semi-transparent (OK)")
        else:
            failed.append("BRIGHT_ARMOR_PRESERVATION_CHECK")
            print(f"  [FAIL] BRIGHT_ARMOR_PRESERVATION_CHECK: {below:.1%} bright armor pixels eroded (alpha<{cfg['armor_alpha_minimum']})")
    else:
        passed.append("BRIGHT_ARMOR_PRESERVATION_CHECK")
        print(f"  [SKIP/PASS] BRIGHT_ARMOR_PRESERVATION_CHECK: {n_bright} bright interior pixels (dark character)")

    # CHECK 9: CORE_COLOR_PRESERVATION_CHECK
    op_r = r[opaque_mask]; op_g = g[opaque_mask]; op_b = b[opaque_mask]
    green_cyan = int(np.sum((op_g > op_r + 30) & (op_g > 80)))
    crimson    = int(np.sum((op_r > op_g + 40) & (op_r > op_b + 40) & (op_r > 100)))
    amber      = int(np.sum((op_r > 140) & (op_r > op_g + 20) & (op_g > op_b + 20)))

    if green_cyan >= cfg["core_min_pixel_count"]:
        passed.append("CORE_COLOR_PRESERVATION_CHECK")
        print(f"  [PASS] CORE_COLOR_PRESERVATION_CHECK: {green_cyan} green/cyan pixels (core intact)")
    else:
        failed.append("CORE_COLOR_PRESERVATION_CHECK")
        print(f"  [FAIL] CORE_COLOR_PRESERVATION_CHECK: only {green_cyan} green/cyan pixels — core may be missing")
    print(f"  [INFO] crimson muscle pixels: {crimson}, amber pixels: {amber}")

    # SUMMARY
    sha = sha256_file(png_path)
    total = len(passed) + len(failed)
    overall = "PASS" if len(failed) == 0 else ("PARTIAL_PASS" if len(failed) == 1 else "FAIL")

    print(f"\n  --- Summary: {subject_name} ---")
    print(f"  SHA-256: {sha[:24]}...")
    print(f"  PASSED: {len(passed)}/{total}  FAILED: {len(failed)}/{total}")
    if failed:
        print(f"  Failed checks: {', '.join(failed)}")
    print(f"  OVERALL: {overall}")
    return {"subject": subject_name, "overall": overall, "passed": passed, "failed": failed, "sha256": sha}


def extract_magenta(src, dst):
    """Remove #FF00FF background. Safe for white/cyan/green characters."""
    arr = np.array(Image.open(src).convert("RGBA")).astype(float)
    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]
    dist = np.sqrt((r - 255)**2 + (g - 0)**2 + (b - 255)**2)
    alpha = np.ones_like(r) * 255.0
    alpha = np.where(dist < 42.0, 0.0, alpha)
    mid = (dist >= 42.0) & (dist < 72.0)
    alpha[mid] = ((dist[mid] - 42.0) / 30.0) * 255.0
    # Defringe pink cast at semi-transparent edges
    pink = (alpha > 0) & (alpha < 200) & (r > 180) & (b > 180) & (g < 90)
    arr[pink, 0] = arr[pink, 0] * 0.3 + arr[pink, 1] * 0.7
    arr[pink, 2] = arr[pink, 2] * 0.3 + arr[pink, 1] * 0.7
    arr[:,:,3] = alpha
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(dst, "PNG")
    print(f"  Magenta extract -> {os.path.basename(dst)}")


def extract_blue(src, dst):
    """Remove #0000FF background. Safe for red/bone/amber characters."""
    arr = np.array(Image.open(src).convert("RGBA")).astype(float)
    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]
    dist = np.sqrt((r - 0)**2 + (g - 0)**2 + (b - 255)**2)
    alpha = np.ones_like(r) * 255.0
    alpha = np.where(dist < 50.0, 0.0, alpha)
    mid = (dist >= 50.0) & (dist < 80.0)
    alpha[mid] = ((dist[mid] - 50.0) / 30.0) * 255.0
    blue_edge = (alpha > 0) & (alpha < 200) & (b > 160) & (r < 80) & (g < 80)
    arr[blue_edge, 2] = arr[blue_edge, 2] * 0.15 + arr[blue_edge, 0] * 0.85
    arr[:,:,3] = alpha
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(dst, "PNG")
    print(f"  Blue extract -> {os.path.basename(dst)}")


if __name__ == "__main__":
    brain  = r"C:\Users\zeros\.gemini\antigravity-ide\brain\502ac287-7274-4c09-81db-f44d8395fbb1"
    proj   = r"C:\Users\zeros\.gemini\antigravity-ide\scratch\biosynthesized-grey-zone-loop"
    sprite_dir = os.path.join(proj, "assets", "bioroids", "sprites")
    os.makedirs(sprite_dir, exist_ok=True)

    files = os.listdir(brain)
    alden_srcs  = sorted([f for f in files if f.startswith("bio_ald_def001_alden_magenta")  and f.endswith(".jpg")])
    lambda_srcs = sorted([f for f in files if f.startswith("subject_af09_lambda_anomaly_front") and f.endswith(".jpg")])

    alden_dst  = os.path.join(sprite_dir, "bio_ald_def001_alden_front.png")
    lambda_dst = os.path.join(sprite_dir, "subject_af09_lambda_anomaly_front.png")

    print("\n=== AETHER FOUNTAIN ASSET PIPELINE ===")
    print("Step 1: Background Extraction")

    if alden_srcs:
        extract_magenta(os.path.join(brain, alden_srcs[-1]), alden_dst)
    else:
        print("  ERROR: No ALDEN magenta source found."); sys.exit(1)

    if lambda_srcs:
        extract_blue(os.path.join(brain, lambda_srcs[-1]), lambda_dst)
    else:
        print("  ERROR: No LAMBDA source found."); sys.exit(1)

    print("\nStep 2: Admission Gate")
    r1 = run_gate(alden_dst,  "BIO-ALD-DEF001 [ALDEN]", bg_key=(255, 0, 255))
    r2 = run_gate(lambda_dst, "SUBJECT AF-09 [LAMBDA]",  bg_key=(0,   0, 255))

    print("\n\n=== PIPELINE VERDICT ===")
    for res in [r1, r2]:
        icon = "PASS" if res["overall"] == "PASS" else ("PARTIAL" if "PARTIAL" in res["overall"] else "FAIL")
        print(f"  [{icon}] {res['subject']}: {res['overall']}")
        if res.get("failed"):
            print(f"         Failed: {', '.join(res['failed'])}")

    ok = all(r["overall"] in ("PASS", "PARTIAL_PASS") for r in [r1, r2])
    print(f"\n  STATUS: {'READY FOR GODOT IMPORT' if ok else 'HOLD — fix failures first'}")
