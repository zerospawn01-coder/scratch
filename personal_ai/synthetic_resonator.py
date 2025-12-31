import numpy as np
import time

class SyntheticLEAPEngine:
    """
    Ultra-Lean Resonator Simulation.
    Demonstrates the 'Leap' logic without loading a 5GB model.
    """
    def __init__(self, vocabulary_size=32000):
        self.vocab_size = vocabulary_size
        self.H_threshold = 2.5
        self.top_k = 50

    def calculate_entropy(self, probs):
        # Top-k entropy only (as per User's 1.8 Law correction)
        top_probs = np.sort(probs)[-self.top_k:]
        top_probs = top_probs / top_probs.sum()
        return -np.sum(top_probs * np.log(top_probs + 1e-10))

    def simulate_step(self, mode="safe"):
        """
        Simulates a single generation step.
        - safe: biased towards high probability (the 'average')
        - leap: uses lambda=2.0 to find the 'valley'
        """
        # 1. Generate a synthetic 'average-heavy' distribution (Power Law)
        # Most of the mass is in a few tokens (the cliche)
        logits = np.random.exponential(scale=1.0, size=self.vocab_size)
        probs = np.exp(logits) / np.sum(np.exp(logits))
        
        entropy = self.calculate_entropy(probs)
        is_leap_triggered = entropy > self.H_threshold
        
        # 2. Selection Logic
        if is_leap_triggered:
            # LEAP mode: lambda = 2.0 (The Resonator)
            # Penalize high probability, reward 'surprising' tokens in the valley
            lambda_val = 2.0
            surprise = -np.log(probs + 1e-10)
            scores = probs - lambda_val * surprise
            selected_token = np.argmin(scores)
            state = "LEAP"
        else:
            # Normal mode: Pick the peak (The Average)
            selected_token = np.argmax(probs)
            state = "AVE "

        return {
            "token": selected_token,
            "entropy": entropy,
            "state": state,
            "prob": probs[selected_token]
        }

def run_demonstration():
    print("=== 1.8 Resonator: Synthetic Phase Transition Demo ===")
    print("Environment: Ultra-Lean (Zero-Model / Zero-Freeze)")
    engine = SyntheticLEAPEngine()
    
    for i in range(10):
        res = engine.simulate_step()
        token_preview = f"ID:{res['token']:05d}"
        print(f"Step {i+1:02d} | Entropy: {res['entropy']:.2f} | State: {res['state']} | Chosen: {token_preview} (P={res['prob']:.4f})")
        time.sleep(0.1) # Human-readable pace

if __name__ == "__main__":
    run_demonstration()
