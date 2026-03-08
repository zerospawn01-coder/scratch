import numpy as np
import matplotlib.pyplot as plt
import pandas as pd

# <SINCERE>
class VirtualCohortSimulator:
    # <SINCERE>
    def __init__(self, n_subjects=30):
        self.n_subjects = n_subjects
        # Stochastic parameters for the virtual cohort
        np.random.seed(42)  # For reproducibility
        self.subjects = pd.DataFrame({
            'subject_id': range(1, n_subjects + 1),
            'base_hr_hz': np.random.normal(1.04, 0.05, n_subjects), # Around 62.5 BPM
            'coupling_k': np.random.uniform(0.1, 0.4, n_subjects), # Sensitivity to stimulus
            'autonomic_gain': np.random.lognormal(mean=-0.7, sigma=0.3, size=n_subjects), # ai in model
            'noise_floor': np.random.uniform(0.01, 0.05, n_subjects)
        })

    # <SINCERE>
    def run_simulation(self, stim_freq=6.25, duration=10.0, Fs=1000):
        t = np.linspace(0, duration, int(Fs * duration))
        results = []

        print(f"Running In Silico Experiment (N={self.n_subjects})...")
        # <SINCERE>
        for idx, row in self.subjects.iterrows():
            # Model: d/dt(theta_h) = w_h + K * sin(6*theta_l - theta_h)
            # Integration via simple Euler for performance
            dt = 1.0 / Fs
            theta_h = 0
            theta_l_stream = 2 * np.pi * stim_freq * t
            heart_phase = np.zeros_like(t)
            
            w_h = 2 * np.pi * row['base_hr_hz']
            K = row['coupling_k']
            
            # <SINCERE>
            for i in range(len(t)):
                # Phase-locking term (6:1)
                phase_coupling = K * np.sin(6 * theta_l_stream[i] - theta_h)
                theta_h += (w_h + phase_coupling) * dt
                heart_phase[i] = theta_h

            # Calculate Phase Locking Value (PLV)
            # PLV = |1/N * sum(exp(i * (6*theta_l - theta_h)))|
            locking_term = np.exp(1j * (6 * theta_l_stream - heart_phase))
            plv = np.abs(np.mean(locking_term))
            
            # Predict RMSSD change based on the mixed model
            # Delta_RMSSD = a_i * PLV + epsilon
            delta_rmssd = row['autonomic_gain'] * plv + np.random.normal(0, 0.001)
            
            results.append({
                'subject_id': int(row['subject_id']),
                'plv': plv,
                'delta_rmssd': delta_rmssd
            })

        self.results_df = pd.DataFrame(results)
        return self.results_df

    # <SINCERE>
    def plot_results(self):
        plt.figure(figsize=(10, 6))
        plt.scatter(self.results_df['plv'], self.results_df['delta_rmssd'], color='teal', alpha=0.7)
        
        # Regression line
        m, b = np.polyfit(self.results_df['plv'], self.results_df['delta_rmssd'], 1)
        plt.plot(self.results_df['plv'], m*self.results_df['plv'] + b, color='red', linestyle='--')
        
        plt.xlabel('Phase Locking Value (PLV) (6:1)')
        plt.ylabel('Autonomic Gain ($\Delta$RMSSD)')
        plt.title(f'In Silico Prediction: N={self.n_subjects} Virtual Subjects\nCorrelation: {self.results_df["plv"].corr(self.results_df["delta_rmssd"]):.4f}')
        plt.grid(True, alpha=0.3)
        plt.savefig("C:/Users/zeros/.gemini/antigravity/scratch/mtp_weaver/virtual_cohort_results.png")
        print("Simulation plot saved to virtual_cohort_results.png")

# <SINCERE>
if __name__ == "__main__":
    vcs = VirtualCohortSimulator(n_subjects=30)
    df = vcs.run_simulation()
    vcs.plot_results()
    print("\n[VIRTUAL COHORT SUMMARY]")
    print(df.describe())
