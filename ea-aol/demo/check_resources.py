import psutil
import time

print("\n" + "="*60)
print("System Resource Check")
print("="*60)

# Wait a moment for stable reading
time.sleep(1)

# CPU
cpu_percent = psutil.cpu_percent(interval=1)
print(f"\nCPU Usage: {cpu_percent}%")

# Memory
mem = psutil.virtual_memory()
print(f"Memory Usage: {mem.percent}%")
print(f"Memory Used: {mem.used / (1024**3):.1f} GB / {mem.total / (1024**3):.1f} GB")

# Python processes
python_procs = [p for p in psutil.process_iter(['name', 'cpu_percent', 'memory_info']) 
                if 'python' in p.info['name'].lower()]

print(f"\nPython Processes: {len(python_procs)}")
for proc in python_procs:
    try:
        mem_mb = proc.info['memory_info'].rss / (1024**2)
        print(f"  - PID {proc.pid}: {mem_mb:.1f} MB")
    except:
        pass

print("\n" + "="*60 + "\n")
