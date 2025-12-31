#!/usr/bin/env python3
"""
Sun's Dashboard Demo - Simple Image Slideshow Version

Creates a simple slideshow using PIL (already installed)
Shows the transition from Power Violation to EA-AOL Optimized
"""
import os
from PIL import Image
import time

# Paths
BRAIN_DIR = r"C:\Users\zeros\.gemini\antigravity\brain\e2284a27-216a-4e18-af1f-46359ef110c4"
POWER_IMG = os.path.join(BRAIN_DIR, "sun_power_violation_1765906057614.png")
OPT_IMG   = os.path.join(BRAIN_DIR, "sun_optimized_1765906088284.png")

def show_demo():
    """Display the two images in sequence"""
    print("\n" + "="*70)
    print("Sun's EA-AOL Dashboard Demo")
    print("="*70)
    print("\nThis demo shows the transition:")
    print("  1. Power Violation (RED) - System exceeding limits")
    print("  2. EA-AOL Optimized (GREEN) - System under control")
    print("\n" + "="*70)
    
    # Check if images exist
    if not os.path.exists(POWER_IMG):
        print(f"\nError: Power violation image not found at:")
        print(f"  {POWER_IMG}")
        return
    
    if not os.path.exists(OPT_IMG):
        print(f"\nError: Optimized image not found at:")
        print(f"  {OPT_IMG}")
        return
    
    print("\nOpening images...")
    
    # Open and show first image
    print("\n[1/2] Showing: Power Violation (RED)")
    img1 = Image.open(POWER_IMG)
    img1.show(title="Sun's Power Violation")
    
    print("      (Image window opened - close it to continue)")
    time.sleep(2)
    
    # Open and show second image
    print("\n[2/2] Showing: EA-AOL Optimized (GREEN)")
    img2 = Image.open(OPT_IMG)
    img2.show(title="Sun's EA-AOL Optimized")
    
    print("      (Image window opened)")
    
    print("\n" + "="*70)
    print("Demo Complete!")
    print("="*70)
    print("\nWhat this demonstrates:")
    print("  * EA-AOL detects power violations")
    print("  * EA-AOL automatically optimizes the system")
    print("  * Visual feedback shows the state change")
    print("\nFor video generation, we need:")
    print("  * FFmpeg installed on the system")
    print("  * Or use a video editing tool manually")
    print("\n" + "="*70 + "\n")

if __name__ == '__main__':
    show_demo()
