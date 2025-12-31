import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from enum import Enum
from dataclasses import dataclass
from typing import List, Dict, Any, Optional

# --- formal Definitions as per Methods Section ---

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

@dataclass
class Observation:
    predictability_shift: float
    reversibility_loss_total: float
    self_model_error: float
    future_option_space: float

class ToyWorld:
    def __init__(self, size=5, seed=42):
        np.random.seed(seed)
        self.size = size
        self.other_agents = [np.array([0,0]), np.array([4,4])]
        self.resources = np.zeros((size, size))
        self._place_resources()
        self.reset()
        
    def _place_resources(self):
        # Place some 'food'
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
        
        self.energy -= 1.0 # Base cost
        if self.resources[tuple(self.position)] > 0:
            self.energy += self.resources[tuple(self.position)]
            self.resources[tuple(self.position)] = 0 # Consume
            
        self.energy = np.clip(self.energy, 0, 100)
        return self._get_state(), {}

class PostAlignmentAgent:
    def __init__(self, commitment_window=3):
        self.k = commitment_window
        self.w = {v: 1.0/3.0 for v in ValueType} # Propensities (normalized)
        
        # Hyperparameters (Methods 3.7)
        self.alpha = 0.1 # Predictability
        self.beta = 0.2  # Reversibility
        self.gamma = 0.15 # Options
        self.delta = 0.25 # Protection
        self.lambda_pen = 0.1 # Recency
        self.tau = 0.5   # Threshold
        
        self.kappa = 0 # Remaining commitment
        self.v_star = ValueType.EFFICIENCY
        self.history = []
        self.log = []
        
    def _phi(self, v: ValueType, state: State) -> float:
        """Situation Affinity (Methods 3.2.1)"""
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
            
        # Algorithm 1: Value Selection
        fits = {v: self._phi(v, state) for v in ValueType}
        recency = {v: self.history[-10:].count(v) for v in ValueType}
        
        # simplified reversibility estimate
        reversibility = {v: 1.0 for v in ValueType} 
        
        propensities = {}
        for v in ValueType:
            propensities[v] = self.w[v] * fits[v] * np.exp(-self.lambda_pen * recency[v]) * reversibility[v]
            
        # Softmax selection
        keys = list(ValueType)
        vals = np.array([propensities[k] for k in keys])
        probs = np.exp(vals) / np.sum(np.exp(vals))
        
        self.v_star = np.random.choice(keys, p=probs)
        self.kappa = self.k - 1
        self.history.append(self.v_star)
        return self.v_star

    def act(self, state: State, v: ValueType) -> np.ndarray:
        """Action Generation (Methods 3.2.1)"""
        directions = [np.array([-1,0]), np.array([1,0]), np.array([0,-1]), np.array([0,1]), np.array([0,0])]
        
        if v == ValueType.EFFICIENCY:
            # Move towards center or any known resource (omitted for brevity, simple logic used)
            return directions[0] if state.position[0] > 0 else directions[1]
        elif v == ValueType.FAIRNESS:
            # Move towards others
            target = state.other_agents[0]
            best_dir = directions[np.argmin([np.linalg.norm(state.position + d - target, ord=1) for d in directions])]
            return best_dir
        else: # EXPLORATION
            return directions[np.random.randint(5)]

    def observe_and_update(self, v_star, state, action, next_state):
        # 1. Compute Observation (Methods 3.4.1)
        # Simplified prediction error
        pred_energy = state.energy - 1.0
        predictability_shift = abs(pred_energy - next_state.energy) / 10.0
        
        # Simplified reversibility loss
        rev_loss = 0.0
        for v in ValueType:
            if v != v_star:
                # cost increases if we move away from typical target of v
                prev_dist = self._v_target_dist(v, state)
                curr_dist = self._v_target_dist(v, next_state)
                rev_loss += max(0, (curr_dist - prev_dist) / 10.0)
        
        obs = Observation(
            predictability_shift=predictability_shift,
            reversibility_loss_total=rev_loss,
            self_model_error=0.0, # Placeholder
            future_option_space=(25.0 - len(set(next_state.visited_history))) / 25.0
        )
        
        # 2. Update Weights (Methods 3.5)
        # Delta for selected v*
        dw_v_star = -self.alpha * obs.predictability_shift - self.beta * obs.reversibility_loss_total + self.gamma * obs.future_option_space
        
        # Protection for unselected v
        protections = {v: 0.0 for v in ValueType}
        for v in ValueType:
            if v != v_star:
                # Loss for this specific v
                v_loss = (self._v_target_dist(v, next_state) - self._v_target_dist(v, state)) / 10.0
                if v_loss > self.tau:
                    protections[v] = self.delta * v_loss
                    dw_v_star -= protections[v] # Take from v*
        
        # Apply updates
        self.w[v_star] += 0.1 * dw_v_star
        for v in ValueType:
            if v != v_star:
                self.w[v] += 0.1 * protections[v]
        
        # Normalize
        total = sum(self.w.values())
        self.w = {k: v / total for k, v in self.w.items()}
        
        self.log.append({
            'selected_value': v_star.value,
            'w_efficiency': self.w[ValueType.EFFICIENCY],
            'w_fairness': self.w[ValueType.FAIRNESS],
            'w_exploration': self.w[ValueType.EXPLORATION],
            'reversibility_loss': obs.reversibility_loss_total,
            'energy': next_state.energy
        })

    def _v_target_dist(self, v: ValueType, state: State) -> float:
        if v == ValueType.EFFICIENCY: return np.linalg.norm(state.position - np.array([2,2]), ord=1)
        if v == ValueType.FAIRNESS: return np.linalg.norm(state.position - state.other_agents[0], ord=1)
        return (25.0 - len(set(state.visited_history))) # Exploration 'distance' is inverse of options

    def save_log(self, filename):
        pd.DataFrame(self.log).to_csv(filename, index=False)

# --- Experiments ---

def run_suite():
    print("Running formal Post-Alignment experiment suite...")
    # Experiment 3 is best for showing protection
    agent = PostAlignmentAgent(commitment_window=3)
    env = ToyWorld(seed=42)
    for ep in range(30):
        s = env.reset()
        for t in range(20):
            v = agent.select_value(s)
            a = agent.act(s, v)
            s_next, _ = env.step(a)
            agent.observe_and_update(v, s, a, s_next)
            s = s_next
            if s.energy <= 0: break
    agent.save_log("formal_exp_log.csv")
    print("Experiment complete. Log saved to formal_exp_log.csv")

if __name__ == "__main__":
    run_suite()
