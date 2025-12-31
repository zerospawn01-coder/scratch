import psutil
import time

print("\n" + "="*70)
print("High CPU/GPU Process Check")
print("="*70)

# Get all processes sorted by CPU usage
processes = []
for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info']):
    try:
        proc.cpu_percent(interval=0.1)  # Initialize
    except:
        pass

time.sleep(2)  # Wait for accurate CPU measurement

for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info']):
    try:
        cpu = proc.cpu_percent(interval=0)
        if cpu > 1.0:  # Only show processes using >1% CPU
            mem_mb = proc.info['memory_info'].rss / (1024**2)
            processes.append({
                'pid': proc.info['pid'],
                'name': proc.info['name'],
                'cpu': cpu,
                'mem': mem_mb
            })
    except:
        pass

# Sort by CPU usage
processes.sort(key=lambda x: x['cpu'], reverse=True)

print(f"\nTop CPU-consuming processes:")
print(f"{'PID':<8} {'Name':<30} {'CPU %':<10} {'Memory (MB)':<12}")
print("-" * 70)

for p in processes[:15]:  # Top 15
    print(f"{p['pid']:<8} {p['name']:<30} {p['cpu']:<10.1f} {p['mem']:<12.1f}")

print("\n" + "="*70)
print(f"Total CPU: {psutil.cpu_percent(interval=1)}%")
print(f"Total Memory: {psutil.virtual_memory().percent}%")
print("="*70 + "\n")
