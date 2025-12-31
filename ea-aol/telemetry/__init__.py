"""
EA-AOL Telemetry Package
"""

from .nvml_collector import NVMLCollector, EPICalculator, GPUMetrics

__version__ = "0.1.0"
__all__ = ['NVMLCollector', 'EPICalculator', 'GPUMetrics']
