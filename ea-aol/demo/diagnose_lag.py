import psutil
import time

print("\n" + "="*70)
print("System Performance Analysis")
print("="*70)

# CPU
print(f"\nCPU Usage: {psutil.cpu_percent(interval=1)}%")
print(f"CPU Count: {psutil.cpu_count()} cores")

# Memory
mem = psutil.virtual_memory()
print(f"\nMemory Usage: {mem.percent}%")
print(f"Memory Available: {mem.available / (1024**3):.1f} GB")
print(f"Memory Total: {mem.total / (1024**3):.1f} GB")

# Disk
disk = psutil.disk_usage('C:\\')
print(f"\nDisk Usage: {disk.percent}%")
print(f"Disk Free: {disk.free / (1024**3):.1f} GB")

# Top CPU processes
print(f"\n{'='*70}")
print("Top 10 CPU-consuming processes:")
print(f"{'PID':<8} {'Name':<35} {'CPU %':<10} {'Memory (MB)':<12}")
print("-" * 70)

processes = []
for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info']):
    try:
        proc.cpu_percent(interval=0)
    except:
        pass

time.sleep(1)

for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info']):
    try:
        cpu = proc.cpu_percent(interval=0)
        mem_mb = proc.info['memory_info'].rss / (1024**2)
        processes.append({
            'pid': proc.info['pid'],
            'name': proc.info['name'][:34],
            'cpu': cpu,
            'mem': mem_mb
        })
    except:
        pass

processes.sort(key=lambda x: x['cpu'], reverse=True)

for p in processes[:10]:
    print(f"{p['pid']:<8} {p['name']:<35} {p['cpu']:<10.1f} {p['mem']:<12.1f}")

print("\n" + "="*70)
print("DIAGNOSIS:")

# Diagnosis
if psutil.cpu_percent(interval=0) > 80:
    print("⚠️  HIGH CPU USAGE - This causes input lag")
if mem.percent > 85:
    print("⚠️  HIGH MEMORY USAGE - This causes system slowdown")
if disk.percent > 90:
    print("⚠️  LOW DISK SPACE - This may cause performance issues")

print("="*70 + "\n")
