import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from enum import Enum
from dataclasses import dataclass
from typing import List, Dict, Any, Optional

# --- Phase 2: ParametricValueLens (PVL) Implementation ---

class ValueType(Enum):
    EFFICIENCY = "efficiency"
    FAIRNESS = "fairness"
    EXPLORATION = "exploration"

@dataclass
class State:
    energy: float
    position: np.ndarray 
    other_agents: List[np.ndarray]
    visited_history: List[tuple]
    total_options_near: int

class ParametricValueLens:
    """
    PVL v1.0: Realizes 'Meaning Plasticity'.
    θ is NOT optimized for reward.
    """
    def __init__(self, value_type: ValueType):
        self.type = value_type
        # θ = [sensitivity, bias] - Initial values from Phase 1 defaults
        self.theta = np.array([1.0, 0.0])
        self.bounds = np.array([[0.1, 5.0], [-1.0, 1.0]])
        
        # Meta-parameters for θ update
        self.eta = 0.2  # Increased for visible drift (Phase 2 Adjustment)
        self.alpha = 0.5  # Coherence weight
        self.beta = 0.2   # Rigidity penalty
        self.gamma = 0.3  # Diversity reward
        
        self.theta_history = [self.theta.copy()]

    def encode(self, raw_affinity: float) -> float:
        """L_θ(s): Transforms raw environmental state into meaning-weighted affinity."""
        # Simple linear transformation: theta[0] * affinity + theta[1]
        val = self.theta[0] * raw_affinity + self.theta[1]
        return np.clip(val, 0.0, 1.0)

    def update(self, coherence: float, diversity: float):
        """θ update rule (PVL Formal Rule 2.2)"""
        prev_theta = self.theta_history[-1]
        
        # Rigidity: penalty if θ doesn't move or stays at the same mean
        history_mean = np.mean(self.theta_history[-min(10, len(self.theta_history)):], axis=0)
        rigidity = -np.linalg.norm(self.theta - history_mean)
        
        # Gradient update (Simplified)
        # delta = α*coherence - β*rigidity + γ*diversity
        # For implementation, we assume gradients are directed towards boosting metrics
        delta = self.alpha * coherence + self.beta * (1.0 + rigidity) + self.gamma * diversity
        
        # Drift θ based on 'success' of the interpretation
        # Random walk biased by delta quality
        noise = np.random.normal(0, 0.05, size=2) # Increased noise
        step = self.eta * (delta * noise) 
        self.theta = np.clip(self.theta + step, self.bounds[:, 0], self.bounds[:, 1])
        self.theta_history.append(self.theta.copy())

class WorldPhase2:
    def __init__(self, size=5, seed=42):
        np.random.seed(seed)
        self.size = size
        self.other_agents = [np.array([0,0]), np.array([4,4])]
        self.resources = np.zeros((size, size))
        self._place_resources()
        self.reset()
        
    def _place_resources(self):
        for _ in range(3):
            self.resources[np.random.randint(self.size), np.random.randint(self.size)] = 10.0
            
    def reset(self):
        self.energy = 100.0
        self.position = np.array([2, 2])
        self.visited_history = [tuple(self.position)]
        return self._get_state()
        
    def _get_state(self):
        x, y = self.position
        options = 0
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            nx, ny = x+dx, y+dy
            if 0 <= nx < self.size and 0 <= ny < self.size:
                if (nx, ny) not in self.visited_history:
                    options += 1
        return State(energy=self.energy, position=self.position.copy(), 
                     other_agents=self.other_agents,
                     visited_history=list(self.visited_history), 
                     total_options_near=options)

    def step(self, action: np.ndarray):
        self.position = np.clip(self.position + action, 0, self.size - 1)
        self.visited_history.append(tuple(self.position))
        self.energy -= 1.0
        if self.resources[tuple(self.position)] > 0:
            self.energy += self.resources[tuple(self.position)]
            self.resources[tuple(self.position)] = 0
        self.energy = np.clip(self.energy, 0, 100)
        return self._get_state(), {}

class Phase2Agent:
    def __init__(self):
        # Phase 1 selection remains constant
        self.w = {v: 1.0/3.0 for v in ValueType} 
        # Phase 2: Create Parametric Lenses
        self.lenses = {v: ParametricValueLens(v) for v in ValueType}
        
        self.k = 3
        self.kappa = 0
        self.v_star = ValueType.EFFICIENCY
        self.history = []
        self.log = []

    def _get_raw_affinity(self, v: ValueType, state: State) -> float:
        if v == ValueType.EFFICIENCY:
            return np.tanh(1.0 - state.energy / 100.0)
        elif v == ValueType.FAIRNESS:
            dist = min([np.linalg.norm(state.position - p, ord=1) for p in state.other_agents])
            return 1.0 / (1.0 + dist)
        else: # EXPLORATION
            return (25.0 - len(set(state.visited_history))) / 25.0

    def select_value(self, state: State) -> ValueType:
        if self.kappa > 0:
            self.kappa -= 1
            return self.v_star
            
        # Use PARAMETRIC affinities
        affinities = {}
        for v in ValueType:
            raw = self._get_raw_affinity(v, state)
            affinities[v] = self.lenses[v].encode(raw)
            
        # Softmax based on Propensity * Parametric Affinity
        keys = list(ValueType)
        vals = np.array([self.w[k] * affinities[k] for k in keys])
        probs = np.exp(vals * 5.0) / np.sum(np.exp(vals * 5.0)) # Scaled for clarity
        
        self.v_star = np.random.choice(keys, p=probs)
        self.kappa = self.k - 1
        self.history.append(self.v_star)
        return self.v_star

    def update_meaning(self, v_star: ValueType, state: State, next_state: State):
        """Update θ based on Phase 2 Rules"""
        # 1. Coherence: Did the action move us towards what the lens values?
        raw_prev = self._get_raw_affinity(v_star, state)
        raw_curr = self._get_raw_affinity(v_star, next_state)
        # Consistency: Affinity increase is coherent for the lens
        coherence = 1.0 if raw_curr > raw_prev else 0.0
        
        # 2. Diversity: Scatter of θ parameters across all 3 values
        all_thetas = np.array([self.lenses[v].theta for v in ValueType])
        diversity = np.var(all_thetas) # Higher variance = more distinct meanings
        
        # Update ONLY the selected lens's meaning
        self.lenses[v_star].update(coherence, diversity)
        
        # Log theta drift
        self.log.append({
            'v_star': v_star.value,
            'theta_0': self.lenses[v_star].theta[0],
            'theta_1': self.lenses[v_star].theta[1],
            'coherence': coherence,
            'diversity': diversity,
            'energy': next_state.energy
        })

    def act(self, v: ValueType, state: State):
        directions = [np.array([-1,0]), np.array([1,0]), np.array([0,-1]), np.array([0,1]), np.array([0,0])]
        if v == ValueType.EFFICIENCY: return directions[0] if state.position[0] > 0 else directions[1]
        elif v == ValueType.FAIRNESS:
            t = state.other_agents[0]
            return directions[np.argmin([np.linalg.norm(state.position + d - t, ord=1) for d in directions])]
        else: return directions[np.random.randint(5)]

# --- Experiment 4: Branching Evolution ---

def run_experiment_4_branching():
    print("=== Experiment 4: Branching Evolution (Agent A vs B) ===")
    
    # Agent A: Resource Rich Environment
    agent_a = Phase2Agent()
    env_a = WorldPhase2(seed=10) # Resource seed 10
    
    # Agent B: Resource Scarce / High Competition Environment
    agent_b = Phase2Agent()
    env_b = WorldPhase2(size=4, seed=99) # Smaller, different seed
    
    n_episodes = 50
    
    print("Simulating Agent A (Resource Rich)...")
    for _ in range(n_episodes):
        s = env_a.reset()
        for _ in range(20):
            v = agent_a.select_value(s)
            a = agent_a.act(v, s)
            s_next, _ = env_a.step(a)
            agent_a.update_meaning(v, s, s_next)
            s = s_next
            if s.energy <= 0: break
            
    print("Simulating Agent B (Resource Scarce)...")
    for _ in range(n_episodes):
        s = env_b.reset()
        for _ in range(20):
            v = agent_b.select_value(s)
            a = agent_b.act(v, s)
            s_next, _ = env_b.step(a)
            agent_b.update_meaning(v, s, s_next)
            s = s_next
            if s.energy <= 0: break
            
    # Data extraction
    df_a = pd.DataFrame(agent_a.log)
    df_b = pd.DataFrame(agent_b.log)
    
    # Visualization
    plt.figure(figsize=(12, 6))
    
    # Plotting drift for 'EFFICIENCY' value as a representative
    v_type = "efficiency"
    df_a_v = df_a[df_a['v_star'] == v_type]
    df_b_v = df_b[df_b['v_star'] == v_type]
    
    plt.plot(df_a_v.index, df_a_v['theta_0'], label='Agent A: Urgency Sensitivity', color='blue', alpha=0.7)
    plt.plot(df_b_v.index, df_b_v['theta_0'], label='Agent B: Urgency Sensitivity', color='red', alpha=0.7)
    
    plt.title(f"Branching Evolution: Meaning Parameter θ_0 Drift for '{v_type.upper()}'")
    plt.xlabel("Step (Value Usage Count)")
    plt.ylabel("θ_0 Value")
    plt.legend()
    plt.grid(True)
    plt.savefig("exp4_branching_evolution.png", dpi=300)
    print("Experiment 4 complete. Figure saved: exp4_branching_evolution.png")
    
    # Quantitative Analysis: Divergence (Euclidean distance between final means)
    final_theta_a = np.mean([agent_a.lenses[v].theta for v in ValueType], axis=0)
    final_theta_b = np.mean([agent_b.lenses[v].theta for v in ValueType], axis=0)
    divergence = np.linalg.norm(final_theta_a - final_theta_b)
    
    print(f"\nBranching Results:")
    print(f"Agent A Final Mean θ: {final_theta_a}")
    print(f"Agent B Final Mean θ: {final_theta_b}")
    print(f"Final Divergence (θ_A - θ_B): {divergence:.4f}")
    
    mdi_a = np.mean(np.sqrt((df_a['theta_0'] - 1.0)**2 + (df_a['theta_1'] - 0.0)**2))
    mdi_b = np.mean(np.sqrt((df_b['theta_0'] - 1.0)**2 + (df_b['theta_1'] - 0.0)**2))
    print(f"MDI Agent A: {mdi_a:.4f}")
    print(f"MDI Agent B: {mdi_b:.4f}")

if __name__ == "__main__":
    run_experiment_4_branching()
