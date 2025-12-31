#!/usr/bin/env python3
"""
EA-AOL Fan Control Demo

This script demonstrates ACTUAL hardware control:
- Read GPU temperature
- Control fan speed based on temperature
- Show real-time feedback

This is REAL hardware interaction, not simulation.
"""

import time
import sys

try:
    import pynvml
    NVML_AVAILABLE = True
except ImportError:
    NVML_AVAILABLE = False
    print("Warning: pynvml not installed. Install with: pip install pynvml")

def init_gpu():
    """Initialize NVIDIA GPU control"""
    if not NVML_AVAILABLE:
        return None
    
    try:
        pynvml.nvmlInit()
        handle = pynvml.nvmlDeviceGetHandleByIndex(0)
        return handle
    except Exception as e:
        print(f"Error initializing GPU: {e}")
        return None

def get_temperature(handle):
    """Get current GPU temperature"""
    try:
        temp = pynvml.nvmlDeviceGetTemperature(handle, pynvml.NVML_TEMPERATURE_GPU)
        return temp
    except Exception as e:
        print(f"Error reading temperature: {e}")
        return None

def get_fan_speed(handle):
    """Get current fan speed (%)"""
    try:
        speed = pynvml.nvmlDeviceGetFanSpeed(handle)
        return speed
    except Exception as e:
        # Some GPUs don't support fan speed reading
        return None

def set_fan_speed(handle, speed_percent):
    """
    Set fan speed (0-100%)
    
    Note: This requires administrator privileges and
    may not work on all GPUs (especially laptops).
    """
    try:
        # This is the ACTUAL hardware control command
        pynvml.nvmlDeviceSetFanSpeed_v2(handle, 0, speed_percent)
        return True
    except Exception as e:
        print(f"Cannot set fan speed: {e}")
        print("This may require:")
        print("  1. Administrator/root privileges")
        print("  2. Desktop GPU (not laptop)")
        print("  3. Driver support for fan control")
        return False

def calculate_fan_speed(temp, temp_min=40, temp_max=80):
    """
    Calculate optimal fan speed based on temperature
    
    This is EA-AOL's decision logic for cooling control.
    """
    if temp < temp_min:
        return 30  # Minimum fan speed
    elif temp > temp_max:
        return 100  # Maximum fan speed
    else:
        # Linear interpolation
        ratio = (temp - temp_min) / (temp_max - temp_min)
        return int(30 + ratio * 70)

def main():
    print("\n" + "="*70)
    print("EA-AOL FAN CONTROL DEMO")
    print("="*70)
    print("\nThis demonstrates REAL hardware control.")
    print("EA-AOL will read GPU temperature and adjust fan speed.\n")
    
    # Initialize GPU
    print("Step 1: Initializing GPU...")
    handle = init_gpu()
    
    if handle is None:
        print("\nNo GPU available. Running in simulation mode...")
        run_simulation()
        return
    
    # Get GPU info
    try:
        name = pynvml.nvmlDeviceGetName(handle)
        print(f"GPU: {name}")
    except:
        print("GPU: Unknown")
    
    # Check if we can control fan
    print("\nStep 2: Testing fan control capability...")
    current_fan = get_fan_speed(handle)
    
    if current_fan is not None:
        print(f"Current fan speed: {current_fan}%")
    else:
        print("Fan speed reading not supported")
    
    # Try to set fan speed
    print("\nStep 3: Attempting fan control...")
    can_control = set_fan_speed(handle, current_fan if current_fan else 50)
    
    if not can_control:
        print("\nFan control not available. Running in monitoring mode...")
        run_monitoring(handle)
        return
    
    # Run control loop
    print("\nStep 4: Running EA-AOL control loop...")
    print("(Press Ctrl+C to stop)\n")
    
    print(f"{'Time':>8} | {'Temp':>6} | {'Fan':>6} | {'Decision'}")
    print("-"*70)
    
    try:
        for i in range(30):
            # Read temperature
            temp = get_temperature(handle)
            
            if temp is None:
                print("Error reading temperature")
                break
            
            # EA-AOL decision logic
            target_fan = calculate_fan_speed(temp)
            
            # Apply decision
            set_fan_speed(handle, target_fan)
            
            # Get actual fan speed
            actual_fan = get_fan_speed(handle)
            
            # Determine action
            if temp > 75:
                decision = "HIGH TEMP - Increase fan"
            elif temp < 50:
                decision = "Cool - Reduce fan"
            else:
                decision = "Normal"
            
            print(f"{i*2:6d}s | {temp:4d}C | {actual_fan if actual_fan else target_fan:4d}% | {decision}")
            
            time.sleep(2)
    
    except KeyboardInterrupt:
        print("\n\nStopped by user")
    
    # Cleanup
    print("\nResetting fan to auto mode...")
    try:
        # Reset to automatic control
        pynvml.nvmlDeviceSetDefaultFanSpeed_v2(handle, 0)
    except:
        pass
    
    pynvml.nvmlShutdown()
    
    print("\n" + "="*70)
    print("Demo complete")
    print("="*70 + "\n")

def run_monitoring(handle):
    """Run in monitoring-only mode"""
    print("\nMonitoring GPU temperature...")
    print("(Press Ctrl+C to stop)\n")
    
    print(f"{'Time':>8} | {'Temp':>6} | {'Recommended Fan':>15}")
    print("-"*70)
    
    try:
        for i in range(30):
            temp = get_temperature(handle)
            
            if temp is None:
                break
            
            # Calculate what EA-AOL would do
            recommended_fan = calculate_fan_speed(temp)
            
            print(f"{i*2:6d}s | {temp:4d}C | {recommended_fan:13d}%")
            
            time.sleep(2)
    
    except KeyboardInterrupt:
        print("\n\nStopped by user")
    
    pynvml.nvmlShutdown()

def run_simulation():
    """Run in simulation mode (no GPU)"""
    print("\nSimulating GPU temperature and fan control...")
    print("(This shows what EA-AOL WOULD do with real hardware)\n")
    
    print(f"{'Time':>8} | {'Temp':>6} | {'Fan':>6} | {'Decision'}")
    print("-"*70)
    
    # Simulate temperature changes
    temps = [45, 50, 55, 60, 65, 70, 75, 80, 78, 75, 70, 65, 60, 55, 50]
    
    for i, temp in enumerate(temps):
        # EA-AOL decision
        fan_speed = calculate_fan_speed(temp)
        
        if temp > 75:
            decision = "HIGH TEMP - Increase fan"
        elif temp < 50:
            decision = "Cool - Reduce fan"
        else:
            decision = "Normal"
        
        print(f"{i*2:6d}s | {temp:4d}C | {fan_speed:4d}% | {decision}")
        
        time.sleep(0.5)
    
    print("\n" + "="*70)
    print("Simulation complete")
    print("="*70)
    print("\nWhat this demonstrates:")
    print("  - EA-AOL reads temperature (40-80C)")
    print("  - EA-AOL calculates optimal fan speed (30-100%)")
    print("  - EA-AOL would send control command to GPU")
    print("\nWith real hardware and permissions, this ACTUALLY controls the fan.")
    print("="*70 + "\n")

if __name__ == '__main__':
    main()
