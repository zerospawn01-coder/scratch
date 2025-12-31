"""
EA-AOL Telemetry - NVML Collector
Collects GPU metrics using NVIDIA Management Library
"""

import time
from typing import Dict, Optional
from dataclasses import dataclass


@dataclass
class GPUMetrics:
    """GPU telemetry metrics"""
    timestamp_us: int
    power_w: float
    temp_gpu_die_c: float
    gpu_freq_mhz: float
    gpu_util_pct: float
    mem_util_pct: float
    mem_used_mb: float
    mem_total_mb: float


class NVMLCollector:
    """NVIDIA GPU metrics collector"""
    
    def __init__(self, device_index: int = 0, mock_mode: bool = False):
        self.device_index = device_index
        self.mock_mode = mock_mode
        self.handle = None
        
        if not mock_mode:
            try:
                import pynvml
                self.pynvml = pynvml
                self._initialize_nvml()
            except ImportError:
                print("Warning: pynvml not available, using mock mode")
                self.mock_mode = True
    
    def _initialize_nvml(self):
        """Initialize NVML library"""
        try:
            self.pynvml.nvmlInit()
            self.handle = self.pynvml.nvmlDeviceGetHandleByIndex(self.device_index)
            print(f"✓ NVML initialized for GPU {self.device_index}")
        except Exception as e:
            print(f"Warning: NVML initialization failed: {e}")
            self.mock_mode = True
    
    def collect(self) -> GPUMetrics:
        """Collect current GPU metrics"""
        if self.mock_mode:
            return self._collect_mock()
        
        try:
            # Power
            power_mw = self.pynvml.nvmlDeviceGetPowerUsage(self.handle)
            power_w = power_mw / 1000.0
            
            # Temperature
            temp_c = self.pynvml.nvmlDeviceGetTemperature(
                self.handle, 
                self.pynvml.NVML_TEMPERATURE_GPU
            )
            
            # GPU frequency
            freq_mhz = self.pynvml.nvmlDeviceGetClockInfo(
                self.handle,
                self.pynvml.NVML_CLOCK_SM
            )
            
            # Utilization
            util = self.pynvml.nvmlDeviceGetUtilizationRates(self.handle)
            gpu_util = util.gpu
            mem_util = util.memory
            
            # Memory
            mem_info = self.pynvml.nvmlDeviceGetMemoryInfo(self.handle)
            mem_used_mb = mem_info.used / (1024 * 1024)
            mem_total_mb = mem_info.total / (1024 * 1024)
            
            return GPUMetrics(
                timestamp_us=int(time.time() * 1e6),
                power_w=power_w,
                temp_gpu_die_c=float(temp_c),
                gpu_freq_mhz=float(freq_mhz),
                gpu_util_pct=float(gpu_util),
                mem_util_pct=float(mem_util),
                mem_used_mb=mem_used_mb,
                mem_total_mb=mem_total_mb
            )
        
        except Exception as e:
            print(f"Warning: NVML collection failed: {e}, using mock")
            return self._collect_mock()
    
    def _collect_mock(self) -> GPUMetrics:
        """Collect mock metrics for testing"""
        import random
        
        return GPUMetrics(
            timestamp_us=int(time.time() * 1e6),
            power_w=120.0 + random.uniform(-10, 10),
            temp_gpu_die_c=65.0 + random.uniform(-5, 5),
            gpu_freq_mhz=1400.0 + random.uniform(-100, 100),
            gpu_util_pct=75.0 + random.uniform(-15, 15),
            mem_util_pct=60.0 + random.uniform(-10, 10),
            mem_used_mb=40000.0,
            mem_total_mb=81920.0
        )
    
    def shutdown(self):
        """Shutdown NVML"""
        if not self.mock_mode and self.pynvml:
            try:
                self.pynvml.nvmlShutdown()
                print("✓ NVML shutdown")
            except:
                pass


class EPICalculator:
    """Energy Per Inference calculator"""
    
    def __init__(self):
        self.energy_accumulator_j = 0.0
        self.token_count = 0
        self.last_timestamp_us = None
    
    def update(self, metrics: GPUMetrics, tokens_generated: int = 1):
        """Update EPI calculation with new metrics"""
        current_time_us = metrics.timestamp_us
        
        if self.last_timestamp_us is not None:
            # Calculate energy consumed since last update
            delta_time_s = (current_time_us - self.last_timestamp_us) / 1e6
            energy_j = metrics.power_w * delta_time_s
            
            self.energy_accumulator_j += energy_j
            self.token_count += tokens_generated
        
        self.last_timestamp_us = current_time_us
    
    def get_epi(self) -> float:
        """Get current EPI (J/token)"""
        if self.token_count == 0:
            return 0.0
        return self.energy_accumulator_j / self.token_count
    
    def reset(self):
        """Reset calculator"""
        self.energy_accumulator_j = 0.0
        self.token_count = 0
        self.last_timestamp_us = None


if __name__ == '__main__':
    # Test collector
    collector = NVMLCollector(mock_mode=True)
    calculator = EPICalculator()
    
    print("Collecting metrics for 5 iterations...")
    for i in range(5):
        metrics = collector.collect()
        calculator.update(metrics, tokens_generated=10)
        
        print(f"\nIteration {i+1}:")
        print(f"  Power: {metrics.power_w:.2f} W")
        print(f"  Temp: {metrics.temp_gpu_die_c:.1f} °C")
        print(f"  GPU Util: {metrics.gpu_util_pct:.1f}%")
        print(f"  EPI: {calculator.get_epi():.4f} J/token")
        
        time.sleep(0.1)
    
    collector.shutdown()
