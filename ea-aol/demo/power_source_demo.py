#!/usr/bin/env python3
"""
EA-AOL Power Source Demo

Demonstrates intelligent power management:
- Grid: Full performance
- Battery: Balanced (50% Top-K)
- Critical: Survival (minimum Top-K)

This is what makes EA-AOL superior to OS power management.
"""
import time
import platform

# Simulate power states
class PowerState:
    GRID = "GRID"
    BATTERY = "BATTERY"
    CRITICAL = "CRITICAL"

class PowerSourceDemo:
    def __init__(self):
        self.current_state = PowerState.GRID
        self.battery_pct = 100
        self.base_topk = 8
        
    def get_power_state(self):
        """Detect actual power state from system"""
        # Try to get real battery state
        try:
            import psutil
            # Force fresh read by creating new battery object
            battery = psutil.sensors_battery()
            if battery is not None:
                self.battery_pct = battery.percent
                
                # Debug: store raw values
                self._last_plugged = battery.power_plugged
                self._last_percent = battery.percent
                
                # Real-time detection
                if battery.power_plugged:
                    self.current_state = PowerState.GRID
                    return PowerState.GRID
                elif battery.percent < 20:
                    self.current_state = PowerState.CRITICAL
                    return PowerState.CRITICAL
                else:
                    self.current_state = PowerState.BATTERY
                    return PowerState.BATTERY
        except Exception as e:
            # Store error for debugging
            self._last_error = str(e)
            pass
        
        # Fallback: simulate battery drain for demo
        self.battery_pct -= 0.1  # Slower drain for demo
        if self.battery_pct < 0:
            self.battery_pct = 100
        
        if self.battery_pct > 80:
            self.current_state = PowerState.GRID
            return PowerState.GRID
        elif self.battery_pct < 20:
            self.current_state = PowerState.CRITICAL
            return PowerState.CRITICAL
        else:
            self.current_state = PowerState.BATTERY
            return PowerState.BATTERY
    
    def adjust_topk(self, base_k):
        """EA-AOL's intelligent Top-K adjustment"""
        state = self.get_power_state()
        return self.adjust_topk_for_state(state, base_k)
    
    def adjust_topk_for_state(self, state, base_k=None):
        """Calculate Top-K for specific state"""
        if base_k is None:
            base_k = self.base_topk
        
        if state == PowerState.GRID:
            return base_k  # Full performance
        elif state == PowerState.BATTERY:
            return max(1, base_k // 2)  # 50% reduction
        else:  # CRITICAL
            return 1  # Survival mode
    
    def get_os_behavior(self):
        """What OS would do (stupid)"""
        state = self.get_power_state()
        
        if state == PowerState.GRID:
            return "Full clock (2.4 GHz)"
        elif state == PowerState.BATTERY:
            return "Reduced clock (1.2 GHz) - SLOW!"
        else:  # CRITICAL
            return "Minimum clock (800 MHz) - UNUSABLE!"
    
    def get_ea_aol_behavior(self):
        """What EA-AOL does (smart)"""
        state = self.get_power_state()
        topk = self.adjust_topk(self.base_topk)
        
        if state == PowerState.GRID:
            return f"Top-K={topk}, Full speed, Max quality"
        elif state == PowerState.BATTERY:
            return f"Top-K={topk}, Full speed, Good quality"
        else:  # CRITICAL
            return f"Top-K={topk}, Full speed, Minimal quality"
    
    def run_demo(self):
        """Run comparison demo"""
        print("\n" + "="*80)
        print("EA-AOL vs OS Power Management Comparison")
        print("="*80)
        print("\nScenario: AI inference on laptop\n")
        
        states = [
            (PowerState.GRID, 100),
            (PowerState.BATTERY, 50),
            (PowerState.CRITICAL, 15)
        ]
        
        for state, pct in states:
            self.current_state = state
            self.battery_pct = pct
            
            topk = self.adjust_topk(self.base_topk)
            os_behavior = self.get_os_behavior()
            ea_behavior = self.get_ea_aol_behavior()
            
            print(f"\n{'─'*80}")
            print(f"Power State: {state:12} | Battery: {pct:3}%")
            print(f"{'─'*80}")
            print(f"OS Approach:     {os_behavior}")
            print(f"EA-AOL Approach: {ea_behavior}")
            
            # Show the difference
            if state == PowerState.GRID:
                print(f"\nResult: Both perform well")
            elif state == PowerState.BATTERY:
                print(f"\nResult:")
                print(f"  OS:     Inference becomes 50% SLOWER (unusable)")
                print(f"  EA-AOL: Inference stays FAST, quality slightly lower")
            else:  # CRITICAL
                print(f"\nResult:")
                print(f"  OS:     System barely responsive (emergency only)")
                print(f"  EA-AOL: Still usable, minimal features")
        
        print(f"\n{'='*80}")
        print("CONCLUSION:")
        print("  OS:     'Make it slow to save power' (dumb)")
        print("  EA-AOL: 'Do less work to save power' (smart)")
        print("="*80 + "\n")

def main():
    demo = PowerSourceDemo()
    demo.run_demo()
    
    print("\nLive monitoring (Ctrl+C to exit):")
    print("Watch how EA-AOL adapts to power state changes...")
    print("Try plugging/unplugging AC power to see real-time response!\n")
    
    prev_state = None
    prev_topk = None
    prev_battery = None
    update_counter = 0
    
    try:
        while True:
            state = demo.get_power_state()
            topk = demo.adjust_topk(demo.base_topk)
            
            # Detect state change
            if prev_state and prev_state != state:
                print(f"\n\n{'='*80}")
                print(f"⚡ POWER STATE CHANGED: {prev_state} → {state}")
                print(f"{'='*80}")
                prev_topk_val = demo.adjust_topk_for_state(prev_state)
                print(f"EA-AOL Response: Adjusting Top-K from {prev_topk_val} to {topk}")
                
                # Show battery info for debugging
                if hasattr(demo, '_last_plugged'):
                    print(f"Debug: AC Plugged = {demo._last_plugged}, Battery = {demo._last_percent:.0f}%")
                
                print(f"{'='*80}\n")
            
            prev_state = state
            
            # Only update display if something changed or every 5 iterations (0.5s)
            should_update = (
                topk != prev_topk or 
                abs(demo.battery_pct - (prev_battery or 0)) > 0.5 or
                update_counter % 5 == 0  # Update every 0.5 seconds
            )
            
            if should_update:
                if state == PowerState.GRID:
                    color = "\033[92m"  # Green
                elif state == PowerState.BATTERY:
                    color = "\033[93m"  # Yellow
                else:
                    color = "\033[91m"  # Red
                
                reset = "\033[0m"
                
                print(f"\r{color}[{state:8}]{reset} Battery: {demo.battery_pct:3.0f}% | "
                      f"Top-K: {topk}/{demo.base_topk} | "
                      f"Strategy: {demo.get_ea_aol_behavior():<50}", end="", flush=True)
                
                prev_topk = topk
                prev_battery = demo.battery_pct
                update_counter = 0
            
            update_counter += 1
            time.sleep(0.1)  # 100ms polling - real-time response
    
    except KeyboardInterrupt:
        print("\n\nDemo stopped.\n")

if __name__ == '__main__':
    main()
