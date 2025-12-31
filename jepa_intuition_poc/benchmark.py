import torch
import time
import numpy as np
from sklearn.neighbors import KNeighborsClassifier
from tqdm import tqdm

def measure_memory(forward_fn, input_tensor, device):
    """
    Measures peak memory usage of the forward function.
    """
    input_tensor = input_tensor.to(device)
    
    if device.type == 'cuda':
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats(device)
        
        with torch.no_grad():
            _ = forward_fn(input_tensor)
            
        peak_mem = torch.cuda.max_memory_allocated(device) / (1024 ** 2)  # MB
    else:
        # Fallback for CPU
        # Simple memory profiling on CPU is less accurate but we can use psutil/tracemalloc if needed
        # For MVP, we emphasize CUDA if available.
        peak_mem = 0.0 # Placeholder
        
    return peak_mem

def measure_latency(forward_fn, input_tensor, device, iterations=1000, warm_up=10):
    """
    Measures average latency of the forward function.
    """
    input_tensor = input_tensor.to(device)
    
    with torch.no_grad():
        # Warm-up
        for _ in range(warm_up):
            _ = forward_fn(input_tensor)
            
        if device.type == 'cuda':
            torch.cuda.synchronize()
            
        start_time = time.time()
        for _ in range(iterations):
            _ = forward_fn(input_tensor)
        
        if device.type == 'cuda':
            torch.cuda.synchronize()
        end_time = time.time()
        
    avg_latency = (end_time - start_time) / iterations * 1000 # ms
    return avg_latency

def extract_latents(extract_fn, loader, device):
    """
    Extracts latents and labels from a data loader.
    extract_fn: x -> z
    """
    latents = []
    labels = []
    
    with torch.no_grad():
        for x, y in tqdm(loader, desc="Extracting latents"):
            x = x.to(device)
            z = extract_fn(x)
            latents.append(z.cpu().numpy())
            labels.append(y.numpy())
            
    return np.concatenate(latents, axis=0), np.concatenate(labels, axis=0)

def eval_knn(train_latents, train_labels, test_latents, test_labels, k=5):
    """
    Evaluates classification accuracy using k-NN in latent space.
    """
    knn = KNeighborsClassifier(n_neighbors=k, metric='euclidean')
    knn.fit(train_latents, train_labels)
    acc = knn.score(test_latents, test_labels)
    return acc

if __name__ == "__main__":
    # This section will be populated once model.py and dataset are ready for trial.
    print("Benchmark functions initialized.")
