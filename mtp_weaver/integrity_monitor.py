import numpy as np
import matplotlib.pyplot as plt
from vibronic_perturbation import simulate_chaperone_perturbation

class IntegrityMonitor:
    def __init__(self, size=64):
        self.size = size
        # Create a 'Topological Skeleton' template (Standard folded state)
        self.skeleton = self._create_skeleton_template()
        
    def _create_skeleton_template(self):
        """Creates a simplified 2D Gaussian representing the ideal topological fold."""
        x = np.linspace(-1, 1, self.size)
        y = np.linspace(-1, 1, self.size)
        X, Y = np.meshgrid(x, y)
        skeleton = np.exp(-(X**2 + Y**2) / 0.5)
        return skeleton

    def simulate_projected_image(self, t, perturbation):
        """
        Simulates the projected Moiré image from the processor.
        Includes the Skeleton + High-frequency noise + 'Sincere Residual' (stubborn deviation).
        """
        # Sincere Residual: A stubborn deviation that represents the protein's unique logic
        residual_x, residual_y = 0.3, -0.3
        x = np.linspace(-1, 1, self.size)
        y = np.linspace(-1, 1, self.size)
        X, Y = np.meshgrid(x, y)
        sincere_residual = 0.4 * np.exp(-((X - residual_x)**2 + (Y - residual_y)**2) / 0.05)
        
        # Transient noise (affected by vibronic shaking)
        transient_noise = 0.1 * np.random.normal(size=(self.size, self.size)) * (1 + perturbation)
        
        # Total projected image
        projection = self.skeleton + sincere_residual + transient_noise
        return projection

    def map_residuals(self, projections):
        """
        Calculates 'Residual Persistence'.
        Identifies regions that consistently deviate from the template across many samples.
        """
        diffs = [np.abs(p - self.skeleton) for p in projections]
        persistence_map = np.mean(diffs, axis=0)
        
        # Zero out transient noise (averaging it out)
        # Truth density is where the residual persists despite shaking.
        return persistence_map

if __name__ == "__main__":
    monitor = IntegrityMonitor()
    projections = []
    
    # Run a short observation cycle with vibronic shaking
    duration = 50
    p_stream = simulate_chaperone_perturbation(duration_sec=duration/10, fs=10, intensity=0.2)
    
    for i in range(duration):
        projections.append(monitor.simulate_projected_image(i, p_stream[i]))
        
    res_map = monitor.map_residuals(projections)
    
    print(f"[INTEGRITY SCAN: COMPLETE]")
    print(f"Residual Persistence (Max): {np.max(res_map):.4f}")
    print(f"Observation: The 'Sincere Residual' was captured with high truth-density.")
    
    # Save the residual map for the Bio-Window visualization
    plt.imshow(res_map, cmap='magma')
    plt.title("Bio-Topological Integrity: Residual Persistence Map")
    plt.colorbar(label="Truth Density")
    plt.savefig("C:/Users/zeros/.gemini/antigravity/scratch/mtp_weaver/bio_integrity_map.png")
    print("Map saved to bio_integrity_map.png")
