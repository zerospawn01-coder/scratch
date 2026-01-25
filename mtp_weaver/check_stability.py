import sys
import numpy as np

def check_stability(freq_file):
    print("--- RTSC STABILITY AUDIT ---")
    threshold = -0.5 # cm^-1
    
    try:
        data = np.loadtxt(freq_file)
        # Assuming format: q_index, freq1, freq2...
        freqs = data[:, 1:]
        min_freq = np.min(freqs)
        
        print(f"Minimum Frequency found: {min_freq:.4f} cm^-1")
        
        if min_freq < threshold:
            print("STATUS: [FAIL]")
            print(f"CRITICAL: Found imaginary mode at {min_freq:.4f} cm^-1.")
            print("Structure is UNSTABLE at ambient pressure.")
            sys.exit(1)
        elif min_freq < 0:
            print("STATUS: [PASS] (Warning: Pure Numerical Noise)")
            print("Structure is STABLE. Small negative values are within the precision moat.")
        else:
            print("STATUS: [PASS]")
            print("Structure is STABLE with high Invariant Moat.")
            
    except Exception as e:
        print(f"AUDITOR ERROR: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python check_stability.py <freq_file>")
    else:
        check_stability(sys.argv[1])
