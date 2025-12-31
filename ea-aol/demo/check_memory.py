import psutil

print("\n" + "="*70)
print("System Memory Analysis")
print("="*70)

# Overall memory
mem = psutil.virtual_memory()
print(f"\nTotal Memory: {mem.total / (1024**3):.1f} GB")
print(f"Used Memory:  {mem.used / (1024**3):.1f} GB ({mem.percent}%)")
print(f"Free Memory:  {mem.available / (1024**3):.1f} GB")

# Top memory consumers
print(f"\n{'='*70}")
print("Top 10 Memory Consumers:")
print(f"{'PID':<8} {'Name':<30} {'Memory (MB)':<12}")
print("-" * 70)

processes = []
for proc in psutil.process_iter(['pid', 'name', 'memory_info']):
    try:
        mem_mb = proc.info['memory_info'].rss / (1024**2)
        processes.append({
            'pid': proc.info['pid'],
            'name': proc.info['name'][:29],
            'mem': mem_mb
        })
    except:
        pass

processes.sort(key=lambda x: x['mem'], reverse=True)

for p in processes[:10]:
    print(f"{p['pid']:<8} {p['name']:<30} {p['mem']:<12.1f}")

print("\n" + "="*70)
print("Recommendation:")
if mem.percent > 85:
    print("  ⚠️  Memory usage is HIGH (>85%)")
    print("  → Close unnecessary applications")
    print("  → Restart browser")
elif mem.percent > 70:
    print("  ⚠️  Memory usage is MODERATE (>70%)")
    print("  → Consider closing some applications")
else:
    print("  ✓  Memory usage is NORMAL")

print("="*70 + "\n")
