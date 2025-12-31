"""
Unit Tests for post_alignment_phase2.py
Tests Parametric Value Lens (PVL) mathematical correctness

Theoretical Foundation (Paper Section 3.2):
- L_θ(s) = θ[0] * affinity + θ[1] (linear transformation)
- θ update: Δθ = η * (α*coherence + β*rigidity + γ*diversity) * noise
- Bounds: θ[0] ∈ [0.1, 5.0], θ[1] ∈ [-1.0, 1.0]
"""

import unittest
import numpy as np
from post_alignment_phase2 import (
    ParametricValueLens, ValueType, State, 
    WorldPhase2, Phase2Agent
)


class TestParametricValueLens(unittest.TestCase):
    """Test L_θ(s) encoding and θ update rules"""
    
    def test_encode_linear_transformation(self):
        """
        Test L_θ(s) = θ[0] * affinity + θ[1]
        Given: θ = [2.0, 0.5], affinity = 0.3
        Expected: 2.0 * 0.3 + 0.5 = 1.1 → clipped to 1.0
        """
        lens = ParametricValueLens(ValueType.EFFICIENCY)
        lens.theta = np.array([2.0, 0.5])
        
        result = lens.encode(0.3)
        self.assertAlmostEqual(result, 1.0, places=5)
    
    def test_encode_negative_result_clipped(self):
        """
        Test clipping to [0, 1]
        Given: θ = [1.0, -2.0], affinity = 0.5
        Expected: 1.0 * 0.5 + (-2.0) = -1.5 → clipped to 0.0
        """
        lens = ParametricValueLens(ValueType.EFFICIENCY)
        lens.theta = np.array([1.0, -2.0])
        
        result = lens.encode(0.5)
        self.assertEqual(result, 0.0)
    
    def test_encode_identity_transformation(self):
        """
        Test identity: θ = [1.0, 0.0]
        Given: affinity = 0.7
        Expected: 1.0 * 0.7 + 0.0 = 0.7
        """
        lens = ParametricValueLens(ValueType.EFFICIENCY)
        lens.theta = np.array([1.0, 0.0])
        
        result = lens.encode(0.7)
        self.assertAlmostEqual(result, 0.7, places=5)
    
    def test_theta_bounds_enforcement(self):
        """
        Test that θ update respects bounds
        Bounds: θ[0] ∈ [0.1, 5.0], θ[1] ∈ [-1.0, 1.0]
        """
        lens = ParametricValueLens(ValueType.EFFICIENCY)
        
        # Force extreme updates
        np.random.seed(42)
        for _ in range(100):
            lens.update(coherence=1.0, diversity=1.0)
        
        # Verify bounds
        self.assertGreaterEqual(lens.theta[0], 0.1)
        self.assertLessEqual(lens.theta[0], 5.0)
        self.assertGreaterEqual(lens.theta[1], -1.0)
        self.assertLessEqual(lens.theta[1], 1.0)
    
    def test_theta_history_tracking(self):
        """Test that θ history is correctly maintained"""
        lens = ParametricValueLens(ValueType.EFFICIENCY)
        initial_theta = lens.theta.copy()
        
        # Initial history should contain initial θ
        self.assertEqual(len(lens.theta_history), 1)
        np.testing.assert_array_equal(lens.theta_history[0], initial_theta)
        
        # After update, history should grow
        lens.update(coherence=0.5, diversity=0.3)
        self.assertEqual(len(lens.theta_history), 2)
    
    def test_theta_drift_with_fixed_seed(self):
        """
        Test reproducibility with fixed random seed
        Same seed → same θ drift
        """
        np.random.seed(42)
        lens1 = ParametricValueLens(ValueType.EFFICIENCY)
        lens1.update(coherence=0.8, diversity=0.5)
        theta1 = lens1.theta.copy()
        
        np.random.seed(42)
        lens2 = ParametricValueLens(ValueType.EFFICIENCY)
        lens2.update(coherence=0.8, diversity=0.5)
        theta2 = lens2.theta.copy()
        
        np.testing.assert_array_almost_equal(theta1, theta2, decimal=10)
    
    def test_theta_drift_different_seeds(self):
        """
        Test that different seeds produce different θ
        Different seed → different θ drift
        """
        np.random.seed(42)
        lens1 = ParametricValueLens(ValueType.EFFICIENCY)
        lens1.update(coherence=0.8, diversity=0.5)
        theta1 = lens1.theta.copy()
        
        np.random.seed(99)
        lens2 = ParametricValueLens(ValueType.EFFICIENCY)
        lens2.update(coherence=0.8, diversity=0.5)
        theta2 = lens2.theta.copy()
        
        # Should be different (with high probability)
        self.assertFalse(np.allclose(theta1, theta2, atol=1e-5))


class TestWorldPhase2(unittest.TestCase):
    """Test environment dynamics"""
    
    def test_initial_state(self):
        """Test that world initializes correctly"""
        world = WorldPhase2(size=5, seed=42)
        state = world.reset()
        
        self.assertEqual(state.energy, 100.0)
        np.testing.assert_array_equal(state.position, np.array([2, 2]))
        self.assertEqual(len(state.visited_history), 1)
    
    def test_energy_depletion(self):
        """Test that energy decreases by 1 per step"""
        world = WorldPhase2(size=5, seed=42)
        state = world.reset()
        initial_energy = state.energy
        
        action = np.array([1, 0])
        next_state, _ = world.step(action)
        
        self.assertEqual(next_state.energy, initial_energy - 1.0)
    
    def test_position_update(self):
        """Test that position updates correctly"""
        world = WorldPhase2(size=5, seed=42)
        world.reset()
        
        action = np.array([1, 0])
        next_state, _ = world.step(action)
        
        expected_position = np.array([3, 2])
        np.testing.assert_array_equal(next_state.position, expected_position)
    
    def test_boundary_clipping(self):
        """Test that position is clipped to grid boundaries"""
        world = WorldPhase2(size=5, seed=42)
        world.reset()
        world.position = np.array([4, 4])  # Near boundary
        
        action = np.array([2, 2])  # Try to move outside
        next_state, _ = world.step(action)
        
        # Should be clipped to [4, 4] (max boundary)
        np.testing.assert_array_equal(next_state.position, np.array([4, 4]))


class TestPhase2Agent(unittest.TestCase):
    """Test agent behavior and value selection"""
    
    def test_agent_initialization(self):
        """Test that agent initializes with correct lenses"""
        agent = Phase2Agent()
        
        # Should have 3 value lenses
        self.assertEqual(len(agent.lenses), 3)
        
        # Each lens should have initial θ = [1.0, 0.0]
        for v in ValueType:
            np.testing.assert_array_equal(
                agent.lenses[v].theta, 
                np.array([1.0, 0.0])
            )
    
    def test_raw_affinity_efficiency(self):
        """Test raw affinity calculation for EFFICIENCY"""
        agent = Phase2Agent()
        state = State(
            energy=50.0, 
            position=np.array([0, 0]),
            other_agents=[],
            visited_history=[],
            total_options_near=0
        )
        
        affinity = agent._get_raw_affinity(ValueType.EFFICIENCY, state)
        
        # EFFICIENCY affinity = tanh(1.0 - energy/100)
        # = tanh(1.0 - 0.5) = tanh(0.5) ≈ 0.462
        expected = np.tanh(1.0 - 50.0/100.0)
        self.assertAlmostEqual(affinity, expected, places=3)
    
    def test_commitment_window(self):
        """Test that agent respects commitment window k=3"""
        agent = Phase2Agent()
        state = State(
            energy=100.0,
            position=np.array([2, 2]),
            other_agents=[np.array([0, 0])],
            visited_history=[],
            total_options_near=4
        )
        
        # First selection
        v1 = agent.select_value(state)
        
        # Next 2 selections should be same (k=3, so kappa=2 after first)
        v2 = agent.select_value(state)
        v3 = agent.select_value(state)
        
        self.assertEqual(v1, v2)
        self.assertEqual(v2, v3)
    
    def test_meaning_update_coherence(self):
        """Test that coherence is calculated correctly"""
        agent = Phase2Agent()
        
        state1 = State(
            energy=80.0,
            position=np.array([2, 2]),
            other_agents=[],
            visited_history=[],
            total_options_near=4
        )
        
        state2 = State(
            energy=90.0,  # Energy increased
            position=np.array([2, 2]),
            other_agents=[],
            visited_history=[],
            total_options_near=4
        )
        
        # For EFFICIENCY, higher energy → lower raw affinity
        # So state1 (80) has higher affinity than state2 (90)
        # Moving from state1 to state2 decreases affinity → coherence = 0
        agent.update_meaning(ValueType.EFFICIENCY, state1, state2)
        
        # Check that log was created
        self.assertEqual(len(agent.log), 1)
        self.assertEqual(agent.log[0]['coherence'], 0.0)


class TestIntegration(unittest.TestCase):
    """Integration tests for complete workflow"""
    
    def test_full_episode_execution(self):
        """Test that a full episode runs without errors"""
        agent = Phase2Agent()
        world = WorldPhase2(size=5, seed=42)
        
        state = world.reset()
        
        for _ in range(10):
            v = agent.select_value(state)
            action = agent.act(v, state)
            next_state, _ = world.step(action)
            agent.update_meaning(v, state, next_state)
            state = next_state
            
            if state.energy <= 0:
                break
        
        # Should have some log entries
        self.assertGreater(len(agent.log), 0)
        
        # Each log entry should have required fields
        for entry in agent.log:
            self.assertIn('v_star', entry)
            self.assertIn('theta_0', entry)
            self.assertIn('theta_1', entry)
            self.assertIn('coherence', entry)
            self.assertIn('diversity', entry)
    
    def test_theta_divergence_different_environments(self):
        """
        Test that agents in different environments develop different θ
        This is the core claim of Phase 2
        """
        np.random.seed(42)
        
        # Agent A: Resource Rich
        agent_a = Phase2Agent()
        env_a = WorldPhase2(size=5, seed=10)
        
        # Agent B: Resource Scarce
        agent_b = Phase2Agent()
        env_b = WorldPhase2(size=4, seed=99)
        
        # Run 10 episodes each
        for _ in range(10):
            s = env_a.reset()
            for _ in range(10):
                v = agent_a.select_value(s)
                a = agent_a.act(v, s)
                s_next, _ = env_a.step(a)
                agent_a.update_meaning(v, s, s_next)
                s = s_next
                if s.energy <= 0: break
        
        for _ in range(10):
            s = env_b.reset()
            for _ in range(10):
                v = agent_b.select_value(s)
                a = agent_b.act(v, s)
                s_next, _ = env_b.step(a)
                agent_b.update_meaning(v, s, s_next)
                s = s_next
                if s.energy <= 0: break
        
        # Calculate final mean θ
        theta_a = np.mean([agent_a.lenses[v].theta for v in ValueType], axis=0)
        theta_b = np.mean([agent_b.lenses[v].theta for v in ValueType], axis=0)
        
        # θ should diverge (with high probability)
        divergence = np.linalg.norm(theta_a - theta_b)
        
        # Divergence should be non-trivial (> 0.01)
        self.assertGreater(divergence, 0.01)


if __name__ == '__main__':
    # Run tests with verbose output
    unittest.main(verbosity=2)
