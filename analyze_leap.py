"""
LEAP Activation Analysis Script
Analyzes execution_log.txt from D drive and generates statistics + visualizations

Phase 2: Statistical Analysis for Manuscript Preparation
"""
import json
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

# Critical threshold (fixed)
K = 1.8

# Load execution log
log_path = Path(r"D:\research\scratch\nature_1.8_law\Aesthetic-Resonator\execution_log.txt")
with open(log_path, 'r') as f:
    logs = [json.loads(line) for line in f]

# Extract data
steps = [log['step'] for log in logs]
entropies = [log['entropy'] for log in logs]
modes = [log['mode'] for log in logs]

# LEAP activation analysis
leap_count = sum(1 for m in modes if m == 'LEAP')
ave_count = sum(1 for m in modes if m == 'AVE')
leap_rate = leap_count / len(modes)

# Entropy statistics
mean_entropy = np.mean(entropies)
std_entropy = np.std(entropies)
min_entropy = np.min(entropies)
max_entropy = np.max(entropies)
threshold_crossings = sum(1 for h in entropies if h > K)

# Print statistics (paper-ready format)
print("=" * 70)
print("LEAP Activation Point Analysis (Phase 2)")
print("=" * 70)
print(f"Critical Threshold K: {K}")
print(f"Total Steps: {len(logs)}")
print(f"LEAP Activations (H > {K}): {leap_count} / {len(logs)} = {leap_rate:.1%}")
print(f"AVE Activations (H ≤ {K}): {ave_count} / {len(logs)} = {(1-leap_rate):.1%}")
print()
print("Entropy Statistics:")
print(f"  Mean H: {mean_entropy:.4f}")
print(f"  Std Dev: {std_entropy:.4f}")
print(f"  Range: [{min_entropy:.4f}, {max_entropy:.4f}]")
print(f"  Threshold Crossings (H > {K}): {threshold_crossings} ({threshold_crossings/len(logs):.1%})")
print()
print("Paper-Ready Statement:")
print(f"  'LEAP mode was activated in {leap_count} of {len(logs)} generation steps")
print(f"   ({leap_rate:.1%}), demonstrating that the K={K} threshold is")
print(f"   consistently exceeded in natural language generation.'")
print("=" * 70)
print()

# Visualization 1: Entropy Distribution
fig, axes = plt.subplots(2, 1, figsize=(10, 10))

# Histogram
axes[0].hist(entropies, bins=20, alpha=0.7, edgecolor='black', color='steelblue')
axes[0].axvline(x=K, color='red', linestyle='--', linewidth=2, label=f'K={K} Threshold')
axes[0].axvline(x=mean_entropy, color='green', linestyle=':', linewidth=2, label=f'Mean H={mean_entropy:.3f}')
axes[0].set_xlabel('Entropy H(P)', fontsize=12)
axes[0].set_ylabel('Frequency', fontsize=12)
axes[0].set_title(f'Entropy Distribution in LEAP Decoder (K={K})', fontsize=14, fontweight='bold')
axes[0].legend(fontsize=10)
axes[0].grid(alpha=0.3)

# Trajectory
colors = ['red' if m == 'LEAP' else 'blue' for m in modes]
axes[1].scatter(steps, entropies, c=colors, alpha=0.6, s=50)
axes[1].axhline(y=K, color='red', linestyle='--', linewidth=2, label=f'K={K} Threshold')
axes[1].set_xlabel('Generation Step', fontsize=12)
axes[1].set_ylabel('Entropy H(P)', fontsize=12)
axes[1].set_title('Entropy Trajectory (Red=LEAP, Blue=AVE)', fontsize=14, fontweight='bold')
axes[1].legend(fontsize=10)
axes[1].grid(alpha=0.3)

plt.tight_layout()
output_path = Path(r"D:\research\scratch\nature_1.8_law\Aesthetic-Resonator\figure_entropy_analysis.png")
plt.savefig(output_path, dpi=300, bbox_inches='tight')
print(f"Figure saved: {output_path}")

# Save statistics to file
stats_path = Path(r"D:\research\scratch\nature_1.8_law\Aesthetic-Resonator\leap_statistics.txt")
with open(stats_path, 'w') as f:
    f.write("LEAP Activation Point Analysis (Phase 2)\n")
    f.write("=" * 70 + "\n")
    f.write(f"Critical Threshold K: {K}\n")
    f.write(f"Total Steps: {len(logs)}\n")
    f.write(f"LEAP Activations (H > {K}): {leap_count} / {len(logs)} = {leap_rate:.1%}\n")
    f.write(f"AVE Activations (H ≤ {K}): {ave_count} / {len(logs)} = {(1-leap_rate):.1%}\n")
    f.write("\n")
    f.write("Entropy Statistics:\n")
    f.write(f"  Mean H: {mean_entropy:.4f}\n")
    f.write(f"  Std Dev: {std_entropy:.4f}\n")
    f.write(f"  Range: [{min_entropy:.4f}, {max_entropy:.4f}]\n")
    f.write(f"  Threshold Crossings (H > {K}): {threshold_crossings} ({threshold_crossings/len(logs):.1%})\n")
    f.write("\n")
    f.write("Paper-Ready Statement:\n")
    f.write(f"  'LEAP mode was activated in {leap_count} of {len(logs)} generation steps\n")
    f.write(f"   ({leap_rate:.1%}), demonstrating that the K={K} threshold is\n")
    f.write(f"   consistently exceeded in natural language generation.'\n")

print(f"Statistics saved: {stats_path}")
