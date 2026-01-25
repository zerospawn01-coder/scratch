import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import find_peaks

class CardioResonanceEngine:
    """
    Models the coupling between heart rhythm (approx 1Hz) and 
    external stimulation (approx 6.25Hz).
    """
    def __init__(self, heart_rate_hz=1.0416, stim_freq_hz=6.25):
        # 6.25 / 1.0416 = 6.0 (The 6:1 ratio)
        self.heart_rate_hz = heart_rate_hz
        self.stim_freq_hz = stim_freq_hz
        self.sampling_rate = 1000
        self.duration = 60  # 60 seconds for RMSSD stability

    def simulate_coupled_rhythm(self, coupling_strength=0.1):
        t = np.linspace(0, self.duration, self.sampling_rate * self.duration)
        
        # 1. Heart Rhythm (Non-linear oscillator)
        heart_signal = np.sin(2 * np.pi * self.heart_rate_hz * t)
        
        # 2. Stimulation Signal
        stim_signal = np.sin(2 * np.pi * self.stim_freq_hz * t)
        
        # 3. Coupled Interaction (Phase Locking Logic)
        # The heart rhythm is modulated by the stim frequency if in sync
        # We model this as a phase perturbation
        coupled_phase = stim_signal * heart_signal * coupling_strength
        result_signal = heart_signal + coupled_phase
        
        return t, result_signal

    def calculate_rmssd(self, signal):
        """
        Extracts peak-to-peak intervals (R-R) and calculates RMSSD.
        """
        peaks, _ = find_peaks(signal, distance=self.sampling_rate * 0.5)
        rr_intervals = np.diff(peaks) / self.sampling_rate
        if len(rr_intervals) < 2: return 0.0
        
        rmssd = np.sqrt(np.mean(np.square(np.diff(rr_intervals))))
        return rmssd

    print(f"[RESONANCE AUDIT: 6:1 COUPLING]")
    
    # Frequency Sweep
    target_hr = 1.0416  # 62.5 BPM
    test_freqs = np.linspace(5.5, 7.0, 30)
    locking_degrees = []

    for f in test_freqs:
        # Measure Phase Locking Value (PLV)
        t = np.linspace(0, 10, 10000)
        heart_phase = 2 * np.pi * target_hr * t
        stim_phase = 2 * np.pi * f * t
        # Lock degree: how close is the ratio to 6.0?
        ratio = f / target_hr
        plv = np.abs(np.mean(np.exp(1j * (stim_phase - 6 * heart_phase))))
        locking_degrees.append(plv)

    plt.figure(figsize=(10, 5))
    plt.plot(test_freqs, locking_degrees, 'g-', marker='o', label='6:1 Locking Degree (PLV)')
    plt.axvline(x=6.25, color='r', linestyle='--', label='6.25Hz Resonance')
    plt.xlabel('Stimulus Frequency (Hz)')
    plt.ylabel('Phase Locking Value (0-1)')
    plt.title('Biological Synchronization: 6:1 Integer Lock at 6.25 Hz')
    plt.grid(True)
    plt.legend()
    plt.savefig("C:/Users/zeros/.gemini/antigravity/scratch/mtp_weaver/locking_degree_sweep.png")

    max_idx = np.argmax(locking_degrees)
    print(f"Peak Locking at: {test_freqs[max_idx]:.2f} Hz")
    print(f"PLV at 6.25 Hz: {locking_degrees[np.argmin(np.abs(test_freqs - 6.25))]:.4f}")
