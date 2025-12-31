#!/usr/bin/env python3
"""
EA-AOL Power + Workload Aware Demo

Combines power state AND workload state for intelligent Top-K adjustment.
"""
import time
import random

class PowerState:
    GRID = "GRID"
    BATTERY = "BATTERY"
    CRITICAL = "CRITICAL"

class WorkloadState:
    IDLE = "IDLE"        # No AI running
    ACTIVE = "ACTIVE"    # Normal inference
    HEAVY = "HEAVY"      # High load

class SmartPowerDemo:
    def __init__(self):
        self.current_power = PowerState.GRID
        self.current_workload = WorkloadState.IDLE
        self.battery_pct = 100
        self.base_topk = 8
        
        # Simulate AI workload
        self.inference_count = 0
        
    def get_power_state(self):
        """Get power state (same as before)"""
        try:
            import psutil
            battery = psutil.sensors_battery()
            if battery is not None:
                self.battery_pct = battery.percent
                if battery.power_plugged:
                    return PowerState.GRID
                elif battery.percent < 20:
                    return PowerState.CRITICAL
                else:
                    return PowerState.BATTERY
        except:
            pass
        
        # Fallback
        if self.battery_pct > 80:
            return PowerState.GRID
        elif self.battery_pct < 20:
            return PowerState.CRITICAL
        else:
            return PowerState.BATTERY
    
    def get_workload_state(self):
        """Detect AI workload (simulated)"""
        # In real implementation, this would check:
        # - GPU utilization
        # - Inference queue length
        # - Recent request rate
        
        # Simulate varying workload
        self.inference_count += random.randint(-2, 3)
        self.inference_count = max(0, self.inference_count)
        
        if self.inference_count == 0:
            return WorkloadState.IDLE
        elif self.inference_count < 5:
            return WorkloadState.ACTIVE
        else:
            return WorkloadState.HEAVY
    
    def calculate_topk(self, power_state, workload_state):
        """Smart Top-K calculation based on BOTH states"""
        
        # No AI running → No resources needed
        if workload_state == WorkloadState.IDLE:
            return 0
        
        # AI is running → Adjust based on power + workload
        if power_state == PowerState.GRID:
            # AC power: Use full resources
            if workload_state == WorkloadState.HEAVY:
                return self.base_topk  # 8
            else:
                return self.base_topk  # 8
        
        elif power_state == PowerState.BATTERY:
            # Battery: Reduce resources
            if workload_state == WorkloadState.HEAVY:
                return self.base_topk * 3 // 4  # 6 (75%)
            else:
                return self.base_topk // 2  # 4 (50%)
        
        else:  # CRITICAL
            # Emergency: Minimal resources
            if workload_state == WorkloadState.HEAVY:
                return 2  # Bare minimum for heavy load
            else:
                return 1  # Absolute minimum
    
    def get_strategy_description(self, power, workload, topk):
        """Human-readable strategy"""
        if workload == WorkloadState.IDLE:
            return "AI idle - No resources allocated"
        
        if power == PowerState.GRID:
            return f"AC power + {workload} → Full performance (Top-K={topk})"
        elif power == PowerState.BATTERY:
            return f"Battery + {workload} → Balanced mode (Top-K={topk})"
        else:
            return f"Critical + {workload} → Survival mode (Top-K={topk})"
    
    def run_demo(self):
        """Run interactive demo"""
        print("\n" + "="*80)
        print("EA-AOL Smart Power Management")
        print("Power State + Workload State = Optimal Top-K")
        print("="*80)
        
        print("\nScenario Matrix:\n")
        print(f"{'Power \\ Workload':<20} {'IDLE':<15} {'ACTIVE':<15} {'HEAVY':<15}")
        print("-" * 80)
        
        for power in [PowerState.GRID, PowerState.BATTERY, PowerState.CRITICAL]:
            row = f"{power:<20}"
            for workload in [WorkloadState.IDLE, WorkloadState.ACTIVE, WorkloadState.HEAVY]:
                topk = self.calculate_topk(power, workload)
                row += f"{topk:<15}"
            print(row)
        
        print("\n" + "="*80)
        print("Key Insight:")
        print("  - IDLE: Top-K=0 (no waste)")
        print("  - ACTIVE: Adjust based on power")
        print("  - HEAVY: Slightly more resources")
        print("="*80 + "\n")
        
        print("Live monitoring (Ctrl+C to exit):")
        print("Watch how EA-AOL adapts to BOTH power AND workload...\n")
        
        try:
            while True:
                power = self.get_power_state()
                workload = self.get_workload_state()
                topk = self.calculate_topk(power, workload)
                strategy = self.get_strategy_description(power, workload, topk)
                
                # Color coding
                if workload == WorkloadState.IDLE:
                    color = "\033[90m"  # Gray
                elif power == PowerState.GRID:
                    color = "\033[92m"  # Green
                elif power == PowerState.BATTERY:
                    color = "\033[93m"  # Yellow
                else:
                    color = "\033[91m"  # Red
                
                reset = "\033[0m"
                
                print(f"\r{color}[{power:8}]{reset} "
                      f"[{workload:6}] "
                      f"Battery: {self.battery_pct:3.0f}% | "
                      f"Top-K: {topk}/{self.base_topk} | "
                      f"{strategy:<60}", end="", flush=True)
                
                time.sleep(0.5)
                
        except KeyboardInterrupt:
            print("\n\nDemo stopped.\n")

def main():
    demo = SmartPowerDemo()
    demo.run_demo()

if __name__ == '__main__':
    main()
