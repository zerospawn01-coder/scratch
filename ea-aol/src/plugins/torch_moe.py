"""
EA-AOL PyTorch MoE Plugin

License: BSD-2-Clause
Version: 0.1.0

Energy-aware Mixture of Experts layer that dynamically adjusts Top-K
based on EA-AOL runtime advice.

This demonstrates the key innovation: AI model parameters (Top-K) are
controlled by a physical constraint solver (EA-AOL runtime).
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
import time
from typing import Optional
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from src.bindings.ea_aol import EAAOLController


class EnergyAwareMoELayer(nn.Module):
    """
    Energy-Aware Mixture of Experts Layer
    
    This layer implements a simplified MoE with dynamic Top-K adjustment
    based on EA-AOL runtime advice.
    
    Key Innovation:
    - Traditional MoE: Top-K is fixed hyperparameter
    - EA-AOL MoE: Top-K adapts to power/latency constraints
    
    Example:
        moe = EnergyAwareMoELayer(
            input_dim=768,
            num_experts=8,
            initial_top_k=4,
            ea_controller=controller
        )
        
        output = moe(input_tensor)
        # Top-K may have changed based on power constraints!
    """
    
    def __init__(
        self,
        input_dim: int,
        num_experts: int = 8,
        initial_top_k: int = 4,
        ea_controller: Optional[EAAOLController] = None,
        expert_hidden_dim: Optional[int] = None
    ):
        """
        Initialize Energy-Aware MoE layer
        
        Args:
            input_dim: Input dimension
            num_experts: Number of expert networks
            initial_top_k: Initial Top-K value
            ea_controller: EA-AOL controller instance
            expert_hidden_dim: Hidden dimension for experts (default: 4*input_dim)
        """
        super().__init__()
        
        self.input_dim = input_dim
        self.num_experts = num_experts
        self.top_k = initial_top_k
        self.ea_controller = ea_controller
        
        if expert_hidden_dim is None:
            expert_hidden_dim = 4 * input_dim
        
        # Expert networks (simplified FFN)
        self.experts = nn.ModuleList([
            nn.Sequential(
                nn.Linear(input_dim, expert_hidden_dim),
                nn.GELU(),
                nn.Linear(expert_hidden_dim, input_dim)
            )
            for _ in range(num_experts)
        ])
        
        # Gating network
        self.gate = nn.Linear(input_dim, num_experts)
        
        # Monitoring state
        self.last_tick_time = time.time()
        self.processed_tokens = 0
        self.tick_interval = 0.5  # 500ms
        
        # Statistics
        self.total_forward_calls = 0
        self.total_tokens_processed = 0
        self.k_changes = []
        
        print(f"[MoE] Initialized with {num_experts} experts, Top-K={initial_top_k}")
    
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Forward pass with dynamic Top-K
        
        Args:
            x: Input tensor [batch_size, seq_len, input_dim]
        
        Returns:
            Output tensor [batch_size, seq_len, input_dim]
        """
        batch_size, seq_len, _ = x.shape
        num_tokens = batch_size * seq_len
        
        self.total_forward_calls += 1
        self.total_tokens_processed += num_tokens
        self.processed_tokens += num_tokens
        
        # ===================================================================
        # EA-AOL Control Loop
        # ===================================================================
        
        if self.ea_controller is not None:
            current_time = time.time()
            elapsed = current_time - self.last_tick_time
            
            # Tick at regular intervals
            if elapsed >= self.tick_interval:
                # Calculate metrics
                throughput_tps = self.processed_tokens / elapsed
                latency_ms = elapsed * 1000 / self.total_forward_calls if self.total_forward_calls > 0 else 0
                
                # Get advice from EA-AOL
                # Note: Power is measured by HAL in C runtime
                # We only report application-level metrics
                advice = self.ea_controller.tick(
                    power=0.0,  # HAL will measure this
                    throughput_tps=throughput_tps,
                    latency_ms=latency_ms,
                    quality=1.0  # Would be measured by quality metric
                )
                
                # Apply advice
                if advice.new_top_k > 0 and advice.new_top_k != self.top_k:
                    old_k = self.top_k
                    self.top_k = advice.new_top_k
                    
                    # Clamp to valid range
                    self.top_k = max(1, min(self.num_experts, self.top_k))
                    
                    self.k_changes.append({
                        'time': current_time,
                        'old_k': old_k,
                        'new_k': self.top_k,
                        'reason': 'power_cap' if advice.violation_detected else 'optimization'
                    })
                    
                    print(f"\n{'='*60}")
                    print(f"[MoE] ⚡ EA-AOL Intervention!")
                    print(f"      Top-K: {old_k} → {self.top_k}")
                    print(f"      Throughput: {throughput_tps:.1f} TPS")
                    print(f"      Latency: {latency_ms:.1f} ms")
                    print(f"{'='*60}\n")
                
                # Reset counters
                self.last_tick_time = current_time
                self.processed_tokens = 0
        
        # ===================================================================
        # MoE Computation
        # ===================================================================
        
        # 1. Gating: Compute expert scores
        gate_logits = self.gate(x)  # [batch, seq, num_experts]
        
        # 2. Select Top-K experts (THIS IS THE DYNAMIC PART!)
        # The value of self.top_k can change during runtime!
        top_k_weights, top_k_indices = torch.topk(
            gate_logits, 
            k=self.top_k, 
            dim=-1
        )  # [batch, seq, top_k]
        
        # 3. Normalize weights
        top_k_weights = F.softmax(top_k_weights, dim=-1)
        
        # 4. Compute expert outputs
        # For efficiency, we only compute selected experts
        # This is where energy savings come from!
        
        # Reshape for batch processing
        flat_x = x.view(-1, self.input_dim)  # [batch*seq, dim]
        flat_indices = top_k_indices.view(-1, self.top_k)  # [batch*seq, top_k]
        flat_weights = top_k_weights.view(-1, self.top_k)  # [batch*seq, top_k]
        
        # Initialize output
        output = torch.zeros_like(flat_x)
        
        # Compute each expert's contribution
        # Note: In production, this would be optimized with sparse operations
        for expert_idx in range(self.num_experts):
            # Find tokens that selected this expert
            mask = (flat_indices == expert_idx).any(dim=1)
            
            if mask.any():
                # Compute expert output for selected tokens
                expert_input = flat_x[mask]
                expert_output = self.experts[expert_idx](expert_input)
                
                # Get weights for this expert
                expert_weights = torch.zeros(flat_x.size(0), device=x.device)
                for k_idx in range(self.top_k):
                    expert_mask = (flat_indices[:, k_idx] == expert_idx)
                    expert_weights[expert_mask] = flat_weights[expert_mask, k_idx]
                
                # Weighted accumulation
                output[mask] += expert_output * expert_weights[mask].unsqueeze(1)
        
        # Reshape back
        output = output.view(batch_size, seq_len, self.input_dim)
        
        return output
    
    def get_stats(self) -> dict:
        """Get layer statistics"""
        return {
            'current_top_k': self.top_k,
            'num_experts': self.num_experts,
            'total_forward_calls': self.total_forward_calls,
            'total_tokens_processed': self.total_tokens_processed,
            'k_changes': self.k_changes,
            'avg_tokens_per_call': self.total_tokens_processed / max(1, self.total_forward_calls)
        }
    
    def print_stats(self):
        """Print layer statistics"""
        stats = self.get_stats()
        
        print("\n" + "="*60)
        print("Energy-Aware MoE Layer Statistics")
        print("="*60)
        print(f"Current Top-K: {stats['current_top_k']}/{stats['num_experts']}")
        print(f"Total Forward Calls: {stats['total_forward_calls']}")
        print(f"Total Tokens Processed: {stats['total_tokens_processed']}")
        print(f"Avg Tokens/Call: {stats['avg_tokens_per_call']:.1f}")
        print(f"\nTop-K Changes: {len(stats['k_changes'])}")
        
        for i, change in enumerate(stats['k_changes']):
            print(f"  [{i+1}] {change['old_k']} → {change['new_k']} ({change['reason']})")
        
        print("="*60 + "\n")


# ============================================================================
# Example Usage
# ============================================================================

if __name__ == '__main__':
    print("="*60)
    print("EA-AOL PyTorch MoE Plugin Test")
    print("="*60 + "\n")
    
    # Initialize EA-AOL controller
    try:
        from src.bindings.ea_aol import EAAOLController
        
        controller = EAAOLController(
            ir_json_path="output/mixtral_secure.ir.json",
            use_simulator=True
        )
        
        print("[Test] EA-AOL controller initialized\n")
    except Exception as e:
        print(f"[Test] Warning: Could not initialize EA-AOL controller: {e}")
        print("[Test] Running without EA-AOL control\n")
        controller = None
    
    # Create MoE layer
    moe = EnergyAwareMoELayer(
        input_dim=768,
        num_experts=8,
        initial_top_k=8,  # Start with all experts
        ea_controller=controller
    )
    
    print("\n" + "="*60)
    print("Simulating inference workload...")
    print("="*60 + "\n")
    
    # Simulate inference loop
    batch_size = 4
    seq_len = 128
    
    for i in range(20):
        # Create dummy input
        x = torch.randn(batch_size, seq_len, 768)
        
        # Forward pass
        output = moe(x)
        
        print(f"[Iteration {i+1:2d}] Processed {batch_size*seq_len} tokens, "
              f"Current Top-K: {moe.top_k}")
        
        # Simulate some delay
        time.sleep(0.1)
    
    # Print statistics
    moe.print_stats()
    
    if controller:
        controller.shutdown()
    
    print("[Test] Complete")
