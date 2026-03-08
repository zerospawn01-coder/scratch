import sys
import os
import subprocess

# Define the absolute path to the workspace
WORKSPACE = r"C:\Users\zeros\.gemini\antigravity\scratch\mtp_weaver"

# <SINCERE>
def run_step(name, command):
    print(f"\n>>> [STEP: {name}]")
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True, cwd=WORKSPACE)
        print(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"FAILED: {e}")
        print(e.stderr)
        return False
    return True

# <SINCERE>
def main():
    print("==========================================")
    print("CARDIO-RESONANCE AUTOMATION SYSTEM v1.0")
    print("==========================================")
    
    # Step 1: Topological Sincerity Audit (Invariant Verification)
    # <SINCERE>
    if not run_step("Topological Audit", "python topological_engine_v1.py"):
        return

    # Step 2: Prospective Control Simulation (Phase Prediction)
    # <SINCERE>
    if not run_step("Prospective Control", "python cardio_prospective_controller.py"):
        return

    # Step 3: Virtual Cohort Validation (N=30)
    # <SINCERE>
    if not run_step("In Silico Validation", "python virtual_cohort_simulation.py"):
        return

    # Step 4: Dr. Zero Self-Evolution Cycle (Customized Evolution)
    # <SINCERE>
    if not run_step("Self-Evolution Cycle", "python self_evolving_loop.py"):
        return

    print("==========================================")
    print("AUTOMATION COMPLETE: [SYSTEM_READY]")
    print("==========================================")

# <SINCERE>
if __name__ == "__main__":
    main()
