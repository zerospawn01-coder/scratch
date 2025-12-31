"""
EA-AOL Compiler - Parser Module
Parses EA-AOL YAML declarations into AST
"""

import yaml
from typing import Dict, Any, Optional
from dataclasses import dataclass
from pathlib import Path


@dataclass
class ParsedDeclaration:
    """Parsed EA-AOL declaration"""
    inference: Dict[str, Any]
    profile: Optional[Dict[str, Any]] = None
    policy: Optional[Dict[str, Any]] = None
    runtime: Optional[Dict[str, Any]] = None
    raw_yaml: str = ""


class ParserError(Exception):
    """Parser error exception"""
    pass


class Parser:
    """EA-AOL YAML parser"""
    
    REQUIRED_INFERENCE_KEYS = {
        'model_id', 'power_cap', 'latency_slo_ms', 'quality_floor'
    }
    
    def __init__(self):
        self.errors = []
    
    def parse_file(self, path: str) -> ParsedDeclaration:
        """Parse EA-AOL YAML file"""
        try:
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            return self.parse_string(content)
        except FileNotFoundError:
            raise ParserError(f"File not found: {path}")
        except Exception as e:
            raise ParserError(f"Failed to read file: {e}")
    
    def parse_string(self, yaml_content: str) -> ParsedDeclaration:
        """Parse EA-AOL YAML string"""
        try:
            data = yaml.safe_load(yaml_content)
        except yaml.YAMLError as e:
            raise ParserError(f"Invalid YAML: {e}")
        
        if not isinstance(data, dict):
            raise ParserError("Root element must be a dictionary")
        
        # Extract sections
        inference = data.get('inference')
        if not inference:
            raise ParserError("Missing required 'inference' section")
        
        # Validate inference section
        self._validate_inference(inference)
        
        return ParsedDeclaration(
            inference=inference,
            profile=data.get('profile'),
            policy=data.get('policy'),
            runtime=data.get('runtime'),
            raw_yaml=yaml_content
        )
    
    def _validate_inference(self, inference: Dict[str, Any]):
        """Validate inference section"""
        if not isinstance(inference, dict):
            raise ParserError("'inference' must be a dictionary")
        
        # Check required keys
        missing_keys = self.REQUIRED_INFERENCE_KEYS - set(inference.keys())
        if missing_keys:
            raise ParserError(
                f"Missing required keys in 'inference': {missing_keys}"
            )
        
        # Validate types
        self._validate_model_id(inference.get('model_id'))
        self._validate_power_cap(inference.get('power_cap'))
        self._validate_latency_slo(inference.get('latency_slo_ms'))
        self._validate_quality_floor(inference.get('quality_floor'))
    
    def _validate_model_id(self, model_id: Any):
        """Validate model_id"""
        if not isinstance(model_id, str):
            raise ParserError("'model_id' must be a string")
        if not model_id.strip():
            raise ParserError("'model_id' cannot be empty")
    
    def _validate_power_cap(self, power_cap: Any):
        """Validate power_cap"""
        # Handle unit suffixes (e.g., "150W")
        if isinstance(power_cap, str):
            power_cap = self._parse_unit(power_cap, 'W')
        
        if not isinstance(power_cap, (int, float)):
            raise ParserError("'power_cap' must be a number")
        
        if power_cap <= 0:
            raise ParserError("'power_cap' must be positive")
    
    def _validate_latency_slo(self, latency_slo: Any):
        """Validate latency_slo_ms"""
        if not isinstance(latency_slo, (int, float)):
            raise ParserError("'latency_slo_ms' must be a number")
        
        if latency_slo <= 0:
            raise ParserError("'latency_slo_ms' must be positive")
    
    def _validate_quality_floor(self, quality_floor: Any):
        """Validate quality_floor"""
        if not isinstance(quality_floor, (int, float)):
            raise ParserError("'quality_floor' must be a number")
        
        if not 0.0 <= quality_floor <= 1.0:
            raise ParserError("'quality_floor' must be between 0.0 and 1.0")
    
    def _parse_unit(self, value: str, expected_unit: str) -> float:
        """Parse value with unit suffix"""
        value = value.strip()
        if value.endswith(expected_unit):
            try:
                return float(value[:-len(expected_unit)])
            except ValueError:
                raise ParserError(
                    f"Invalid number format: {value}"
                )
        else:
            try:
                return float(value)
            except ValueError:
                raise ParserError(
                    f"Expected number or number with '{expected_unit}' unit: {value}"
                )


def parse_ea_aol(source: str) -> ParsedDeclaration:
    """
    Convenience function to parse EA-AOL YAML
    
    Args:
        source: File path or YAML string
    
    Returns:
        ParsedDeclaration object
    """
    parser = Parser()
    
    # Check if source is a file path
    if '\n' not in source and Path(source).exists():
        return parser.parse_file(source)
    else:
        return parser.parse_string(source)


if __name__ == '__main__':
    # Test parser
    test_yaml = """
inference:
  model_id: "llama-13b"
  power_cap: 150W
  latency_slo_ms: 20
  quality_floor: 0.95
  orchestrator:
    layers: ["sparse", "moe"]
    dvfs_granularity: "token"

profile:
  model_cost:
    flop_per_token: 1.2e9

policy:
  prefer:
    - "min_energy"
"""
    
    try:
        result = parse_ea_aol(test_yaml)
        print("✓ Parse successful")
        print(f"  Model: {result.inference['model_id']}")
        print(f"  Power cap: {result.inference['power_cap']}")
    except ParserError as e:
        print(f"✗ Parse failed: {e}")
