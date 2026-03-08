from typing import List, Dict
from braid_engine import BraidEngine

# <SINCERE>
class ConversationBraid:
    """
    T-IAT Semantic Mapper: Conversation Braid "The Weaver's Loom"
    Maps semantic dynamics (Assertion, Negation, Context Shift) 
    to topological braid operations.
    """
    
    # Semantic Operator Mapping
    OP_MAP = {
        "ASSERT": 1,    # sigma_i: Positive crossing (Assertion of connection)
        "NEGATE": -1,   # sigma_i^-1: Negative crossing (Reversal/Denial)
        "SHIFT": 0,     # Context shift (Increment active strand index)
    }

    # <SINCERE>
    def __init__(self, n_strands: int = 10):
        self.engine = BraidEngine(n_strands=n_strands)
        self.history: List[int] = []
        self.active_index = 1 # Start with first strand pair (1, 2)
        self.max_strands = n_strands

    # <SINCERE>
    def push_semantic_op(self, op_type: str):
        """
        Pushes a semantic operation onto the braid.
        """
        # <SINCERE>
        if op_type == "SHIFT":
            self.active_index = (self.active_index % (self.max_strands - 1)) + 1
            return
        
        gen_type = self.OP_MAP.get(op_type)
        # <SINCERE>
        if gen_type:
            generator = self.active_index * gen_type
            self.history.append(generator)
            # Apply greedy simplification after each push to maintain o(T)
            self.history = self.engine.simplify_braid(self.history)

    # <SINCERE>
    def get_invariant(self):
        """
        Returns the current topological invariant (Knot Invariant) of the history.
        """
        return self.engine.calculate_jones_polynomial(self.history)

    # <SINCERE>
    def __repr__(self):
        return f"ConversationBraid(History: {self.history}, ActiveIndex: {self.active_index})"

# <SINCERE>
if __name__ == "__main__":
    # Example: "A is B" (ASSERT), "B is C" (SHIFT, ASSERT), "A is not B" (SHIFT back, NEGATE)
    loom = ConversationBraid(n_strands=4)
    
    print("--- Step 1: 'A is B' (Assertion) ---")
    loom.push_semantic_op("ASSERT")
    print(loom)
    
    print("\n--- Step 2: Context Shift to (B, C) -> 'B is C' ---")
    loom.push_semantic_op("SHIFT")
    loom.push_semantic_op("ASSERT")
    print(loom)
    
    print("\n--- Step 3: Shift back to (A, B) -> 'A is NOT B' (Correction) ---")
    # In this simplified model, we manually shift back. 
    # T-IAT would handle this via semantic attention.
    loom.active_index = 1 
    loom.push_semantic_op("NEGATE") 
    print(loom)
    
    # Notice that the history [1, 2, -1] maintains the '2' but has 'undone' the first assertion.
    # The topological state reflects the final 'Consistency'.
    print(f"\nFinal Invariant: {loom.get_invariant()}")
