import numpy as np

def resonator_demo():
    print("=== 1.8 Resonator: 'AI Sense' Demonstration (v2) ===")
    print("Objective: Selecting the 'Meaningful Leap' while avoiding 'Literal Noise'.\n")

    # Mock vocabulary: (Word, Probability P)
    # The '1.8 Law' implies we want a balance between Probability (Grammar) 
    # and Information (Inspiration).
    
    tokens = [
        {"text": "The",        "p": 0.450,  "type": "Cliche"},
        {"text": "A",          "p": 0.250,  "type": "Safe"},
        {"text": "Silence",    "p": 0.080,  "type": "Meaningful Leap"},
        {"text": "Whisper",    "p": 0.040,  "type": "Meaningful Leap"},
        {"text": "Shadow",     "p": 0.020,  "type": "Creative"},
        {"text": "Xy-7",       "p": 0.001,  "type": "Noise"},
        {"text": "!!!!",       "p": 0.0001, "type": "Noise"},
    ]

    # Rule 1: Survival Guard (Top-K / Significance)
    # We ignore the bottom 20% of the long tail to stay 'Living' (within grammar)
    TOP_K = 5 
    
    sorted_tokens = sorted(tokens, key=lambda x: x['p'], reverse=True)
    living_tokens = sorted_tokens[:TOP_K]
    
    print(f"Top-{TOP_K} 'Living' Universe selected. (Ignoring Noise tokens: {[t['text'] for t in sorted_tokens[TOP_K:]]})\n")

    print(f"{'Token':<12} | {'P (Prob)':<8} | {'I (Info)':<8} | {'1.8 Score':<10} | {'Status'}")
    print("-" * 65)

    for t in living_tokens:
        p = t['p']
        i = -np.log(p + 1e-10)
        # Score = P - 1.8 * I (Minimized is better)
        score = p - 1.8 * i
        t['score'] = score
        t['i'] = i
        
        status = "Argmax (Normal AI)" if p == max(tok['p'] for tok in living_tokens) else ""
        print(f"{t['text']:<12} | {p:<8.3f} | {i:<8.2f} | {score:<10.2f} | {status}")

    # Optimal "Sense" choice
    best_token = min(living_tokens, key=lambda x: x['score'])
    
    print("-" * 65)
    print(f"\n[Normal AI Choice]: '{living_tokens[0]['text']}' (Predictable)")
    print(f"[Sense AI Choice ]: '{best_token['text']}' (The '1.8 Law' Resonated!)")
    
    print(f"\nConclusion:")
    print(f"By applying K=1.8 within the 'Living' boundary (Top-K), the AI transforms from")
    print(f"a 'Stochastic Parrot' (picking {living_tokens[0]['text']}) into a 'Sense-Maker'.")
    print(f"It selects '{best_token['text']}' because it provides the MOST information gain")
    print(f"relative to its probability, without crossing into the chaos of pure noise.")

if __name__ == "__main__":
    resonator_demo()
