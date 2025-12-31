import numpy as np

def softmax(x):
    e_x = np.exp(x - np.max(x))
    return e_x / e_x.sum(axis=-1, keepdims=True)

def valley_sampling_numpy(
    logits: np.ndarray,
    lambda_jump: float = 1.8,
    top_k: int = 50,
    temperature: float = 1.0,
):
    """
    Lightweight 1.8 Resonator Kernel (NumPy version)
    Designed for 70k JPY PC environments.
    """
    # 1. Temperature-scaled Softmax
    probs = softmax(logits / temperature)

    # 2. Get Top-K indices to ensure "Survival" (grammaticality)
    top_idx = np.argsort(probs)[-top_k:][::-1]
    top_probs = probs[top_idx]

    # 3. Calculate "Surprise" (Self-information)
    # Higher surprise = rarer event = potential "Leap"
    surprise = -np.log(top_probs + 1e-9)

    # 4. Define "Commonness" (The trap of the average)
    commonness = top_probs

    # 5. Resonator Score: Penalty for being too common + Reward for surprises
    # score = D(y|P) - lambda * S(y)
    # We want to MINIMIZE this score to find the optimal "Leap"
    scores = commonness - lambda_jump * surprise

    # 6. Select the token that resonates best with the "Leap" logic
    choice_idx = np.argmin(scores)
    
    return top_idx[choice_idx]

# --- Minimal Test ---
if __name__ == "__main__":
    # Mock logits for a vocabulary of 1000
    mock_logits = np.random.randn(1000)
    
    # Run the resonator
    token_id = valley_sampling_numpy(mock_logits, lambda_jump=1.8)
    
    print(f"Selected Token ID: {token_id}")
    print(f"Logic: λ=1.8 Resonator activated on lean hardware.")
