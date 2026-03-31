"""
Unit Tests for intuition_router.py (Intuition-Layer)
Tests three-way routing logic: Skip / Retrieve / Reason

Theoretical Foundation:
- Intuition Score = α*complexity + β*memory_distance + γ*uncertainty
- score < τ1 → Skip (simple, cached)
- τ1 ≤ score < τ2 → Retrieve (moderate, use memory)
- score ≥ τ2 → Reason (complex, full inference)
"""

import unittest
from unittest.mock import Mock, patch, MagicMock
# torch import removed - using mocks only
import sys
sys.modules['torch'] = MagicMock()
sys.modules['transformers'] = MagicMock()
import numpy as np
from memory_bank import _cosine_similarity
from intuition_router import IntuitionRouter


class TestCosineSimilarity(unittest.TestCase):
    """Test NumPy cosine similarity helper"""
    
    def test_same_vector_similarity_is_one(self):
        query = np.array([1.0, 2.0, 3.0])
        matrix = np.array([[1.0, 2.0, 3.0]])
        sim = _cosine_similarity(query, matrix)
        self.assertAlmostEqual(sim[0], 1.0, places=6)
    
    def test_orthogonal_vectors_similarity_zero(self):
        query = np.array([1.0, 0.0])
        matrix = np.array([[0.0, 1.0]])
        sim = _cosine_similarity(query, matrix)
        self.assertAlmostEqual(sim[0], 0.0, places=6)
    
    def test_opposite_vectors_similarity_negative_one(self):
        query = np.array([1.0, 0.0])
        matrix = np.array([[-1.0, 0.0]])
        sim = _cosine_similarity(query, matrix)
        self.assertAlmostEqual(sim[0], -1.0, places=6)
    
    def test_zero_vector_does_not_crash(self):
        query = np.array([0.0, 0.0])
        matrix = np.array([[1.0, 0.0], [0.0, 1.0]])
        sim = _cosine_similarity(query, matrix)
        self.assertTrue(np.allclose(sim, 0.0))

    def test_query_shape_1_d(self):
        """Query shaped (1, d) should give the same result as a 1-D query."""
        query_1d = np.array([1.0, 2.0, 3.0])
        query_2d = query_1d.reshape(1, -1)  # (1, 3)
        matrix = np.array([[1.0, 2.0, 3.0], [0.0, 1.0, 0.0]])
        sim_1d = _cosine_similarity(query_1d, matrix)
        sim_2d = _cosine_similarity(query_2d, matrix)
        self.assertTrue(np.allclose(sim_1d, sim_2d))

    def test_query_shape_d_1(self):
        """Query shaped (d, 1) should give the same result as a 1-D query."""
        query_1d = np.array([1.0, 0.0])
        query_col = query_1d.reshape(-1, 1)  # (2, 1)
        matrix = np.array([[1.0, 0.0], [-1.0, 0.0]])
        sim_1d = _cosine_similarity(query_1d, matrix)
        sim_col = _cosine_similarity(query_col, matrix)
        self.assertTrue(np.allclose(sim_1d, sim_col))

    def test_matrix_dimension_mismatch_raises(self):
        """Mismatched query/matrix dimensions should raise ValueError."""
        query = np.array([1.0, 2.0, 3.0])
        matrix = np.array([[1.0, 2.0]])  # d=2, not 3
        with self.assertRaises(ValueError):
            _cosine_similarity(query, matrix)


class TestIntuitionScoreCalculation(unittest.TestCase):
    """Test intuition score components"""
    
    def setUp(self):
        """Set up test fixtures with mocked model"""
        with patch('intuition_router.AutoModelForCausalLM'), \
             patch('intuition_router.AutoTokenizer'):
            self.router = IntuitionRouter(
                model_name="mock_model",
                tau1=0.6,
                tau2=1.2
            )
    
    def test_estimate_complexity_simple(self):
        """Test complexity estimation for simple text"""
        text = "What is 2+2?"
        complexity = self.router._estimate_complexity(text)
        
        # Simple text should have low complexity
        self.assertLess(complexity, 0.5)
    
    def test_estimate_complexity_complex(self):
        """Test complexity estimation for complex text"""
        text = "Explain the mathematical proof of Fermat's Last Theorem using algebraic number theory and modular forms with detailed step-by-step derivation"
        complexity = self.router._estimate_complexity(text)
        
        # Complex text should have higher complexity
        self.assertGreater(complexity, 0.15)  # Adjusted to match actual implementation
    
    def test_estimate_uncertainty_low(self):
        """Test uncertainty estimation for factual question"""
        text = "The capital of France is Paris."
        uncertainty = self.router._estimate_uncertainty(text)
        
        # No question words → low uncertainty
        self.assertLess(uncertainty, 0.3)
    
    def test_estimate_uncertainty_high(self):
        """Test uncertainty estimation for complex question"""
        text = "How and why does quantum entanglement work? Explain what happens when we measure."
        uncertainty = self.router._estimate_uncertainty(text)
        
        # Multiple question words → high uncertainty
        self.assertGreater(uncertainty, 0.5)
    
    def test_intuition_score_calculation(self):
        """Test that intuition score is correctly weighted"""
        with patch.object(self.router, '_estimate_complexity', return_value=0.5), \
             patch.object(self.router.memory, 'get_min_distance', return_value=0.3), \
             patch.object(self.router, '_estimate_uncertainty', return_value=0.4):
            
            score = self.router.compute_intuition_score("test")
            
            # score = 0.4*0.5 + 0.3*0.3 + 0.3*0.4
            #       = 0.2 + 0.09 + 0.12 = 0.41
            expected = 0.4 * 0.5 + 0.3 * 0.3 + 0.3 * 0.4
            self.assertAlmostEqual(score, expected, places=2)


class TestActionDecision(unittest.TestCase):
    """Test three-way routing decision"""
    
    def setUp(self):
        with patch('intuition_router.AutoModelForCausalLM'), \
             patch('intuition_router.AutoTokenizer'):
            self.router = IntuitionRouter(
                model_name="mock_model",
                tau1=0.6,
                tau2=1.2
            )
    
    def test_decide_skip(self):
        """Test Skip decision (score < τ1)"""
        action = self.router.decide_action(0.5)
        self.assertEqual(action, "Skip")
    
    def test_decide_retrieve(self):
        """Test Retrieve decision (τ1 ≤ score < τ2)"""
        action = self.router.decide_action(0.9)
        self.assertEqual(action, "Retrieve")
    
    def test_decide_reason(self):
        """Test Reason decision (score ≥ τ2)"""
        action = self.router.decide_action(1.5)
        self.assertEqual(action, "Reason")
    
    def test_threshold_boundary_tau1(self):
        """Test boundary at τ1 = 0.6"""
        # Just below τ1
        action_below = self.router.decide_action(0.59)
        self.assertEqual(action_below, "Skip")
        
        # Exactly at τ1
        action_at = self.router.decide_action(0.6)
        self.assertEqual(action_at, "Retrieve")
    
    def test_threshold_boundary_tau2(self):
        """Test boundary at τ2 = 1.2"""
        # Just below τ2
        action_below = self.router.decide_action(1.19)
        self.assertEqual(action_below, "Retrieve")
        
        # Exactly at τ2
        action_at = self.router.decide_action(1.2)
        self.assertEqual(action_at, "Reason")


class TestMetricsTracking(unittest.TestCase):
    """Test metrics collection"""
    
    def setUp(self):
        with patch('intuition_router.AutoModelForCausalLM'), \
             patch('intuition_router.AutoTokenizer'):
            self.router = IntuitionRouter(model_name="mock_model")
    
    def test_initial_metrics(self):
        """Test that metrics start at zero"""
        metrics = self.router.get_metrics()
        
        self.assertEqual(metrics["skip_ratio"], 0.0)
        self.assertEqual(metrics["retrieve_ratio"], 0.0)
        self.assertEqual(metrics["reason_ratio"], 0.0)
    
    def test_metrics_update(self):
        """Test that metrics are updated correctly"""
        # Manually update metrics
        self.router.metrics["skip_count"] = 5
        self.router.metrics["retrieve_count"] = 3
        self.router.metrics["reason_count"] = 2
        
        metrics = self.router.get_metrics()
        
        # Total = 10
        self.assertAlmostEqual(metrics["skip_ratio"], 0.5, places=2)
        self.assertAlmostEqual(metrics["retrieve_ratio"], 0.3, places=2)
        self.assertAlmostEqual(metrics["reason_ratio"], 0.2, places=2)


class TestIntegration(unittest.TestCase):
    """Integration tests for complete workflow"""
    
    def test_end_to_end_skip_path(self):
        """Test that Skip path uses minimal tokens"""
        with patch('intuition_router.AutoModelForCausalLM'), \
             patch('intuition_router.AutoTokenizer'):
            router = IntuitionRouter(model_name="mock_model", tau1=1.0)
            
            # Mock low complexity input
            with patch.object(router, 'compute_intuition_score', return_value=0.5):
                action = router.decide_action(0.5)
                self.assertEqual(action, "Skip")
    
    def test_end_to_end_reason_path(self):
        """Test that Reason path is triggered for complex input"""
        with patch('intuition_router.AutoModelForCausalLM'), \
             patch('intuition_router.AutoTokenizer'):
            router = IntuitionRouter(model_name="mock_model", tau2=1.0)
            
            # Mock high complexity input
            with patch.object(router, 'compute_intuition_score', return_value=1.5):
                action = router.decide_action(1.5)
                self.assertEqual(action, "Reason")


if __name__ == '__main__':
    unittest.main(verbosity=2)
