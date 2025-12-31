#!/usr/bin/env python3
"""
EA-AOL Real-Time Monitoring Dashboard

License: BSD-2-Clause
Version: 0.1.0

Real-time visualization of EA-AOL metrics including EPI, power, latency, and quality.
"""

import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.gridspec import GridSpec
import json
import time
from collections import deque
from pathlib import Path
import argparse


class EPIMonitor:
    """Real-time EPI and metrics monitoring dashboard"""
    
    def __init__(self, max_points=60, update_interval_ms=500):
        """
        Initialize monitor
        
        Args:
            max_points: Maximum number of data points to display
            update_interval_ms: Update interval in milliseconds
        """
        self.max_points = max_points
        self.update_interval_ms = update_interval_ms
        
        # Data buffers
        self.time_data = deque(maxlen=max_points)
        self.epi_data = deque(maxlen=max_points)
        self.power_data = deque(maxlen=max_points)
        self.latency_data = deque(maxlen=max_points)
        self.quality_data = deque(maxlen=max_points)
        self.k_data = deque(maxlen=max_points)
        
        self.start_time = time.time()
        
        # Setup plot
        self._setup_plot()
    
    def _setup_plot(self):
        """Setup matplotlib figure and axes"""
        self.fig = plt.figure(figsize=(14, 10))
        self.fig.suptitle('EA-AOL Real-Time Monitoring Dashboard', 
                         fontsize=16, fontweight='bold')
        
        gs = GridSpec(3, 2, figure=self.fig, hspace=0.3, wspace=0.3)
        
        # EPI plot (top left)
        self.ax_epi = self.fig.add_subplot(gs[0, 0])
        self.ax_epi.set_title('Energy Per Inference (EPI)', fontweight='bold')
        self.ax_epi.set_ylabel('EPI (J/token)')
        self.ax_epi.grid(True, alpha=0.3)
        
        # Power plot (top right)
        self.ax_power = self.fig.add_subplot(gs[0, 1])
        self.ax_power.set_title('GPU Power Consumption', fontweight='bold')
        self.ax_power.set_ylabel('Power (W)')
        self.ax_power.grid(True, alpha=0.3)
        
        # Latency plot (middle left)
        self.ax_latency = self.fig.add_subplot(gs[1, 0])
        self.ax_latency.set_title('Inference Latency (P99)', fontweight='bold')
        self.ax_latency.set_ylabel('Latency (ms)')
        self.ax_latency.grid(True, alpha=0.3)
        
        # Quality plot (middle right)
        self.ax_quality = self.fig.add_subplot(gs[1, 1])
        self.ax_quality.set_title('Model Quality', fontweight='bold')
        self.ax_quality.set_ylabel('Quality Score')
        self.ax_quality.set_ylim([0, 1.1])
        self.ax_quality.grid(True, alpha=0.3)
        
        # MoE Top-K plot (bottom, spans both columns)
        self.ax_k = self.fig.add_subplot(gs[2, :])
        self.ax_k.set_title('MoE Expert Selection (Top-K)', fontweight='bold')
        self.ax_k.set_xlabel('Time (s)')
        self.ax_k.set_ylabel('Active Experts (k)')
        self.ax_k.set_ylim([0, 9])
        self.ax_k.grid(True, alpha=0.3)
    
    def update(self, frame):
        """Update plots with new data"""
        # Fetch telemetry
        telemetry = self._fetch_telemetry()
        
        if telemetry is None:
            return
        
        # Update time
        current_time = time.time() - self.start_time
        self.time_data.append(current_time)
        
        # Extract metrics (handle both old and new format)
        if 'metrics' in telemetry:
            # Old format (mock data)
            metrics = telemetry.get('metrics', {})
            status = telemetry.get('status', {})
            
            self.epi_data.append(metrics.get('epi_j_per_token', 0))
            self.power_data.append(metrics.get('power_w', 0))
            self.latency_data.append(metrics.get('latency_p99_ms', 0))
            self.quality_data.append(metrics.get('quality_score', 1.0))
            self.k_data.append(status.get('active_k', 4))
            violation = status.get('violation')
        else:
            # New format (from runtime socket)
            self.epi_data.append(telemetry.get('epi_j_per_token', 0))
            self.power_data.append(telemetry.get('power_w', 0))
            self.latency_data.append(telemetry.get('latency_ms', 0))
            self.quality_data.append(telemetry.get('quality', 1.0))
            self.k_data.append(telemetry.get('active_k', 4))
            violation = telemetry.get('violation')
            if violation == 'none':
                violation = None
        
        # Update EPI plot
        self.ax_epi.clear()
        self.ax_epi.plot(list(self.time_data), list(self.epi_data), 
                        'b-', linewidth=2, label='EPI')
        self.ax_epi.axhline(y=4.0, color='r', linestyle='--', 
                           linewidth=1, label='Target: 4.0 J/tok')
        self.ax_epi.set_title('Energy Per Inference (EPI)', fontweight='bold')
        self.ax_epi.set_ylabel('EPI (J/token)')
        self.ax_epi.legend(loc='upper right')
        self.ax_epi.grid(True, alpha=0.3)
        
        # Update Power plot
        self.ax_power.clear()
        self.ax_power.plot(list(self.time_data), list(self.power_data), 
                          'g-', linewidth=2, label='Power')
        self.ax_power.axhline(y=180.0, color='r', linestyle='--', 
                             linewidth=1, label='Cap: 180W')
        self.ax_power.set_title('GPU Power Consumption', fontweight='bold')
        self.ax_power.set_ylabel('Power (W)')
        self.ax_power.legend(loc='upper right')
        self.ax_power.grid(True, alpha=0.3)
        
        # Update Latency plot
        self.ax_latency.clear()
        self.ax_latency.plot(list(self.time_data), list(self.latency_data), 
                            'm-', linewidth=2, label='Latency P99')
        self.ax_latency.axhline(y=50.0, color='r', linestyle='--', 
                               linewidth=1, label='SLO: 50ms')
        self.ax_latency.set_title('Inference Latency (P99)', fontweight='bold')
        self.ax_latency.set_ylabel('Latency (ms)')
        self.ax_latency.legend(loc='upper right')
        self.ax_latency.grid(True, alpha=0.3)
        
        # Update Quality plot
        self.ax_quality.clear()
        self.ax_quality.plot(list(self.time_data), list(self.quality_data), 
                            'c-', linewidth=2, label='Quality')
        self.ax_quality.axhline(y=0.90, color='r', linestyle='--', 
                               linewidth=1, label='Floor: 0.90')
        self.ax_quality.set_title('Model Quality', fontweight='bold')
        self.ax_quality.set_ylabel('Quality Score')
        self.ax_quality.set_ylim([0.8, 1.05])
        self.ax_quality.legend(loc='lower right')
        self.ax_quality.grid(True, alpha=0.3)
        
        # Update MoE Top-K plot
        self.ax_k.clear()
        self.ax_k.step(list(self.time_data), list(self.k_data), 
                      'orange', linewidth=2, where='post', label='Active k')
        self.ax_k.set_title('MoE Expert Selection (Top-K)', fontweight='bold')
        self.ax_k.set_xlabel('Time (s)')
        self.ax_k.set_ylabel('Active Experts (k)')
        self.ax_k.set_ylim([0, 9])
        self.ax_k.legend(loc='upper right')
        self.ax_k.grid(True, alpha=0.3)
        
        # Add status text
        violation = status.get('violation')
        if violation:
            self.fig.text(0.5, 0.02, f'⚠️  VIOLATION: {violation}', 
                         ha='center', fontsize=12, color='red', fontweight='bold')
    
    def _fetch_telemetry(self):
        """Fetch telemetry data from runtime via socket"""
        # Try to read from socket if available
        if hasattr(self, '_socket_file') and self._socket_file:
            try:
                line = self._socket_file.readline()
                if line:
                    return json.loads(line)
            except Exception as e:
                # Socket disconnected, fall back to mock
                self._socket_file = None
                print(f"[Monitor] Socket disconnected: {e}")
        
        # Try to connect to socket
        if not hasattr(self, '_socket') or self._socket is None:
            try:
                import platform
                if platform.system() == 'Windows':
                    # Windows named pipe
                    import win32pipe
                    import win32file
                    pipe_path = r'\\.\pipe\ea_aol'
                    self._socket = win32file.CreateFile(
                        pipe_path,
                        win32file.GENERIC_READ,
                        0,
                        None,
                        win32file.OPEN_EXISTING,
                        0,
                        None
                    )
                    print(f"[Monitor] Connected to Windows pipe: {pipe_path}")
                else:
                    # Unix domain socket
                    socket_path = "/tmp/ea_aol.sock"
                    self._socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                    self._socket.connect(socket_path)
                    self._socket_file = self._socket.makefile('r')
                    print(f"[Monitor] Connected to Unix socket: {socket_path}")
                    
                    # Try to read first line
                    line = self._socket_file.readline()
                    if line:
                        return json.loads(line)
            except Exception as e:
                # Connection failed, use mock data
                pass
        
        # Fall back to mock data
        return self._generate_mock_data()
    
    def _generate_mock_data(self):
        """Generate mock telemetry data (fallback when runtime not available)"""
        import random
        
        # Simulate realistic behavior
        base_power = 150.0
        base_epi = 3.3
        
        # Simulate occasional power spikes
        if random.random() < 0.1:  # 10% chance of spike
            power = base_power + random.uniform(30, 50)
            epi = base_epi + random.uniform(0.5, 1.0)
            k = 3  # Reduced due to power cap
            violation = "power_cap"
            action = "reduce_top_k"
        else:
            power = base_power + random.uniform(-10, 10)
            epi = base_epi + random.uniform(-0.2, 0.2)
            k = 4  # Normal
            violation = None
            action = None
        
        return {
            'timestamp_ms': int(time.time() * 1000),
            'power_w': power,
            'temp_c': 65.0 + random.uniform(-5, 5),
            'freq_mhz': 1500.0 + random.uniform(-100, 100),
            'util': 0.7 + random.uniform(-0.1, 0.1),
            'throughput_tps': 45.0 + random.uniform(-5, 5),
            'epi_j_per_token': epi,
            'latency_ms': 48.0 + random.uniform(-3, 3),
            'quality': 0.92 + random.uniform(-0.02, 0.02),
            'active_k': k,
            'violation': violation if violation else 'none',
            'current_action': action if action else 'none'
        }
    
    def run(self):
        """Start the monitoring dashboard"""
        ani = animation.FuncAnimation(
            self.fig, 
            self.update, 
            interval=self.update_interval_ms, 
            blit=False
        )
        plt.tight_layout(rect=[0, 0.03, 1, 0.96])
        plt.show()


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='EA-AOL Real-Time Monitoring Dashboard'
    )
    parser.add_argument(
        '--max-points', 
        type=int, 
        default=60,
        help='Maximum number of data points to display (default: 60)'
    )
    parser.add_argument(
        '--update-interval', 
        type=int, 
        default=500,
        help='Update interval in milliseconds (default: 500)'
    )
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("EA-AOL Real-Time Monitoring Dashboard")
    print("=" * 60)
    print(f"Max points: {args.max_points}")
    print(f"Update interval: {args.update_interval}ms")
    print("=" * 60)
    print("\nStarting dashboard...")
    print("(Close window to exit)\n")
    
    monitor = EPIMonitor(
        max_points=args.max_points,
        update_interval_ms=args.update_interval
    )
    monitor.run()


if __name__ == '__main__':
    main()
