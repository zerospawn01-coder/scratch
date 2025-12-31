import psutil
import os

print("\n" + "="*70)
print("Cleanup: Stopping all demo processes")
print("="*70)

killed = 0
for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
    try:
        if 'python' in proc.info['name'].lower():
            cmdline = proc.info.get('cmdline', [])
            if cmdline and any('demo' in str(arg).lower() for arg in cmdline):
                print(f"Stopping PID {proc.pid}: {' '.join(cmdline[-2:])}")
                proc.terminate()
                killed += 1
    except:
        pass

print(f"\nStopped {killed} demo process(es)")
print("="*70 + "\n")
