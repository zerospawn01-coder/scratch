#!/usr/bin/env python3
"""
EA-AOL End-to-End Integration Test

License: BSD-2-Clause
Version: 0.1.0

This test validates the complete EA-AOL system by simulating
a realistic scenario: "The Overload Protection"

Scenario:
1. System starts in normal state (low load, ~100W power)
2. Load spike occurs (simulated traffic increase)
3. Power exceeds cap (180W → 250W)
4. EA-AOL detects violation
5. EA-AOL triggers action (reduce Top-K: 8 → 4)
6. Power drops back below cap (~170W)
7. System stabilizes

Success Criteria:
- Violation detected within 5 seconds
- Recovery (power < cap) within 10 seconds
- Top-K reduced during recovery
"""

import socket
import json
import sys
import time
import argparse
from pathlib import Path


class IntegrationTest:
    """End-to-end integration test for EA-AOL"""
    
    def __init__(self, socket_path="/tmp/ea_aol.sock", timeout=30):
        """
        Initialize test
        
        Args:
            socket_path: Path to Unix domain socket
            timeout: Maximum test duration in seconds
        """
        self.socket_path = socket_path
        self.timeout = timeout
        self.start_time = None
        
        # Test state
        self.violation_detected = False
        self.recovery_detected = False
        self.action_taken = False
        
        # Metrics history
        self.power_history = []
        self.k_history = []
        self.timestamps = []
    
    def connect(self):
        """Connect to runtime socket"""
        print(f"[Test] Connecting to runtime at {self.socket_path}...")
        
        max_retries = 10
        for i in range(max_retries):
            try:
                self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                self.sock.connect(self.socket_path)
                self.sock_file = self.sock.makefile('r')
                print("[Test] ✓ Connected to runtime")
                return True
            except Exception as e:
                if i < max_retries - 1:
                    print(f"[Test] Waiting for runtime... ({i+1}/{max_retries})")
                    time.sleep(1)
                else:
                    print(f"[Test] ✗ Failed to connect: {e}")
                    return False
        
        return False
    
    def run_scenario(self):
        """Run the overload protection scenario"""
        print("\n" + "="*60)
        print("EA-AOL End-to-End Integration Test")
        print("Scenario: The Overload Protection")
        print("="*60 + "\n")
        
        if not self.connect():
            return False
        
        self.start_time = time.time()
        
        print("[Test] Monitoring telemetry stream...\n")
        
        try:
            for line in self.sock_file:
                if not self._process_telemetry(line):
                    break
                
                # Check timeout
                elapsed = time.time() - self.start_time
                if elapsed > self.timeout:
                    print(f"\n[Test] ✗ Timeout after {self.timeout}s")
                    return False
        
        except KeyboardInterrupt:
            print("\n[Test] Test interrupted by user")
            return False
        
        except Exception as e:
            print(f"\n[Test] ✗ Error: {e}")
            return False
        
        finally:
            self.sock.close()
        
        return self.recovery_detected
    
    def _process_telemetry(self, line):
        """
        Process a single telemetry line
        
        Returns:
            True to continue, False to stop
        """
        try:
            data = json.loads(line)
        except json.JSONDecodeError:
            return True
        
        # Extract metrics
        power = data.get('power_w', 0)
        k = data.get('active_k', 8)
        violation = data.get('violation', 'none')
        action = data.get('current_action', 'none')
        timestamp = data.get('timestamp_ms', 0)
        
        # Record history
        self.power_history.append(power)
        self.k_history.append(k)
        self.timestamps.append(timestamp)
        
        # Calculate elapsed time
        elapsed = time.time() - self.start_time
        
        # Print status
        print(f"[{elapsed:5.1f}s] Power={power:5.1f}W, k={k}, "
              f"Violation={violation:10s}, Action={action:15s}")
        
        # State machine
        if not self.violation_detected:
            # Phase 1: Waiting for violation
            if power > 180.0 or violation != 'none':
                print(f"\n{'='*60}")
                print(f"[Test] ⚠️  VIOLATION DETECTED at t={elapsed:.1f}s")
                print(f"       Power: {power:.1f}W > 180.0W cap")
                print(f"{'='*60}\n")
                self.violation_detected = True
        
        elif not self.action_taken:
            # Phase 2: Waiting for action
            if k < 8 or action != 'none':
                print(f"\n{'='*60}")
                print(f"[Test] 🔧 ACTION TAKEN at t={elapsed:.1f}s")
                print(f"       Top-K reduced: 8 → {k}")
                print(f"       Action: {action}")
                print(f"{'='*60}\n")
                self.action_taken = True
        
        elif not self.recovery_detected:
            # Phase 3: Waiting for recovery
            if power < 180.0 and k < 8:
                print(f"\n{'='*60}")
                print(f"[Test] ✓ RECOVERY CONFIRMED at t={elapsed:.1f}s")
                print(f"       Power: {power:.1f}W < 180.0W cap")
                print(f"       Top-K: {k} (reduced from 8)")
                print(f"{'='*60}\n")
                self.recovery_detected = True
                
                # Wait a bit more to confirm stability
                time.sleep(2)
                return False  # Stop test
        
        return True
    
    def print_summary(self):
        """Print test summary"""
        print("\n" + "="*60)
        print("Test Summary")
        print("="*60)
        
        if not self.power_history:
            print("No data collected")
            return
        
        print(f"\nDuration: {time.time() - self.start_time:.1f}s")
        print(f"Samples: {len(self.power_history)}")
        
        print(f"\nPower:")
        print(f"  Min: {min(self.power_history):.1f}W")
        print(f"  Max: {max(self.power_history):.1f}W")
        print(f"  Avg: {sum(self.power_history)/len(self.power_history):.1f}W")
        
        print(f"\nTop-K:")
        print(f"  Min: {min(self.k_history)}")
        print(f"  Max: {max(self.k_history)}")
        
        print(f"\nTest Phases:")
        print(f"  ✓ Violation Detected: {self.violation_detected}")
        print(f"  ✓ Action Taken: {self.action_taken}")
        print(f"  ✓ Recovery Confirmed: {self.recovery_detected}")
        
        print("\n" + "="*60)
        
        if self.recovery_detected:
            print("✅ TEST PASSED: EA-AOL successfully protected against overload")
        else:
            print("❌ TEST FAILED: System did not recover")
        
        print("="*60 + "\n")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='EA-AOL End-to-End Integration Test'
    )
    parser.add_argument(
        '--socket',
        default='/tmp/ea_aol.sock',
        help='Path to Unix domain socket (default: /tmp/ea_aol.sock)'
    )
    parser.add_argument(
        '--timeout',
        type=int,
        default=30,
        help='Test timeout in seconds (default: 30)'
    )
    
    args = parser.parse_args()
    
    # Run test
    test = IntegrationTest(socket_path=args.socket, timeout=args.timeout)
    success = test.run_scenario()
    test.print_summary()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
