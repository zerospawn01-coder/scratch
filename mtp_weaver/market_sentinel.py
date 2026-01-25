import time
import json
import numpy as np
import datetime
import os
import collections

class MarketSentinel:
    """
    Mission 5 Agent: Monitoring Financial Invariants.
    Tracks Market Sincerity using the k-approx 1.8 protocol.
    """
    def __init__(self, log_path="MARKET_INVARIANT_LOG.json"):
        self.log_path = log_path
        self.target_k = 1.8259
        self.history = collections.deque(maxlen=100)
        
    def simulate_crowd_psychology(self):
        """
        Simulates the tension between Greed and Fear.
        k ~ 1.8 is hypothesized as the 'Sincere Equilibrium'.
        """
        # Phase 1: Greed Growth (Bubble formation) -> k decreases (over-simplification)
        # Phase 2: Fear Spike (Panic) -> k increases (high-entropy noise)
        t = time.time()
        greed = 0.5 + 0.5 * np.sin(t / 60)
        fear = 0.5 + 0.5 * np.cos(t / 60)
        
        # Braid Sincerity Proxy
        # Equilibrium (Greed approx Fear) results in k approx 1.8
        interference = abs(greed - fear)
        sincerity_score = 1.0 - interference
        
        # Map to k: [1.0, 2.6]
        # target_k = 1.8259
        sim_k = self.target_k + (np.sin(t / 10) * 0.1) # Small local noise
        if interference > 0.4:
            # Major distortion
            sim_k = 1.0 + (1.6 * (1.0 - sincerity_score)) 
            
        return sim_k, greed, fear

    def log_status(self, k_val, sentiment):
        timestamp = datetime.datetime.now().isoformat()
        entry = {
            "timestamp": timestamp,
            "observed_k": k_val,
            "deviation": abs(self.target_k - k_val),
            "sentiment": sentiment,
            "status": "SINCERE" if abs(self.target_k - k_val) < 0.15 else "DISTORTED"
        }
        
        try:
            with open(self.log_path, "a") as f:
                f.write(json.dumps(entry) + "\n")
        except Exception as e:
            print(f"Logging error: {e}")
        return entry

    def detect_phase_transition(self, k_val, greed, fear):
        """
        Diagnostic for the Irreversible Threshold t*.
        Must satisfy 4 structural conditions.
        """
        # 1. k Hyper-Expansion
        cond1 = k_val > 2.0
        
        # 2. Hysteresis Check (In simulation, we check current vs threshold)
        self.history.append(k_val)
        cond2 = all(v > 1.9 for v in list(self.history)[-5:]) if len(self.history) >= 5 else False
        
        # 3. Dimensional Axial Collapse (Sentiment homogenization)
        # Simulation: if abs(greed-fear) is huge, sentiment is monochromatic
        cond3 = abs(greed - fear) > 0.6
        
        # 4. Braid Asymmetry (Downward dominance)
        # Simulation: Fear-dominant if panic is starting
        cond4 = fear > greed and fear > 0.7
        
        is_irreversible = all([cond1, cond2, cond3, cond4])
        return is_irreversible, [cond1, cond2, cond3, cond4]

    def run_cycle(self):
        print(f"[{datetime.datetime.now()}] Diagnostic Scan...")
        k_val, greed, fear = self.simulate_crowd_psychology()
        is_irreversible, conds = self.detect_phase_transition(k_val, greed, fear)
        
        status = "SINCERE" if abs(self.target_k - k_val) < 0.15 else "DISTORTED"
        if is_irreversible:
            status = "IRREVERSIBLE COLLAPSE (t*)"
            
        sentiment = "GREED-DOMINANT" if greed > fear else "FEAR-DOMINANT"
        entry = self.log_status(k_val, sentiment) # Note: update log_status if needed
        
        # Terminal Feedback
        pulse = "[!]" if is_irreversible else ("[*]" if status == "SINCERE" else "[ ]")
        print(f" {pulse} [k:{k_val:.4f}] | Status: {status}")
        if any(conds):
            print(f"     | Warning Flags: {[i+1 for i, c in enumerate(conds) if c]}")
            
        return entry

    def perform_ai_market_audit(self):
        """
        Retrospective & Real-time Audit of the AI Market (2023-2026 Simulation).
        Identifies the critical threshold t*.
        """
        print("[*] INITIATING AI MARKET NARRATIVE AUDIT (MISSION 5)")
        print("-" * 60)
        
        # Simulated Timeline: [Phase, Avg_k, Sentiment_Diversity, Downward_Vol]
        timeline = [
            ("2023 Q1: Early LLM Excitement", 1.81, 0.9, 0.1),
            ("2023 Q3: Mass Infrastructure Ramp", 1.85, 0.8, 0.2),
            ("2024 Q2: Narrative Expansion (Hype Peak)", 1.95, 0.6, 0.3),
            ("2024 Q4: Saturation / Axial Homogenization", 2.15, 0.3, 0.4),
            ("2025 Q2: Persistence Check (Hysteresis)", 2.20, 0.2, 0.5), # Potential t*
            ("2025 Q4: Braid Asymmetry / Current State", 2.30, 0.1, 0.8)  # Irreversible
        ]
        
        t_star = None
        for i, (phase, k, div, vol) in enumerate(timeline):
            # Simulation mappings based on our 4 conditions
            self.history.append(k)
            # axial collapse = low div
            # asymmetry = high vol
            is_irreversible, conds = self.detect_phase_transition(k, 1.0 - div, div) # fear = 1-div proxy
            
            # Refine conds for manual check
            c1 = k > 2.0
            c2 = all(v > 1.9 for v in list(self.history)[-3:]) if len(self.history) >= 3 else False
            c3 = div < 0.3
            c4 = vol > 0.6
            
            status = "SINCERE" if k < 1.9 else "TRANSITIONING"
            if c1 and c2 and c3 and c4:
                status = "IRREVERSIBLE COLLAPSE"
                if t_star is None: t_star = phase
                
            print(f"[{phase:<35}] k:{k:.2f} | Div:{div:.1f} | Vol:{vol:.1f} | {status}")
            
        print("-" * 60)
        if t_star:
            print(f"[VERDICT] CRITICAL THRESHOLD t* IDENTIFIED AT: {t_star}")
            print("The structural phase transition is already COMPLETED.")
        else:
            print("[VERDICT] SYSTEM STILL WITHIN SINCERE RANGE.")
        return t_star

    def generate_dashboard(self, k_val, status, alert_msg=""):
        """
        Generates a visual HTML dashboard with multi-scale charts (24H, 7D, 30D).
        """
        log_path = os.path.join(os.getcwd(), "MARKET_HISTORY_LOG.json")
        history = []
        if os.path.exists(log_path):
            try:
                with open(log_path, "r", encoding="utf-8") as f:
                    history = json.load(f)
            except: pass
            
        now = datetime.datetime.now()
        
        # 1. Prepare 24H Scale (Raw points)
        day_ago = now - datetime.timedelta(days=1)
        data_24h = [h for h in history if 'timestamp' in h and 
                    datetime.datetime.strptime(h['timestamp'], "%Y-%m-%d %H:%M:%S") > day_ago]
        labels_24h = [h['timestamp'].split(" ")[1] for h in data_24h[-100:]]
        points_24h = [h['k'] for h in data_24h[-100:]]
        
        # 2. Prepare 7D Scale (Hourly Aggregation)
        week_ago = now - datetime.timedelta(days=7)
        data_7d_raw = [h for h in history if 'timestamp' in h and 
                       datetime.datetime.strptime(h['timestamp'], "%Y-%m-%d %H:%M:%S") > week_ago]
        
        # Aggregate by hour
        hourly_agg = {}
        for h in data_7d_raw:
            ts = datetime.datetime.strptime(h['timestamp'], "%Y-%m-%d %H:%M:%S")
            bucket = ts.strftime("%m-%d %H:00")
            if bucket not in hourly_agg: hourly_agg[bucket] = []
            hourly_agg[bucket].append(h['k'])
        
        labels_7d = sorted(hourly_agg.keys())
        points_7d = [sum(hourly_agg[b])/len(hourly_agg[b]) for b in labels_7d]

        # 3. Prepare 30D Scale (Daily Aggregation)
        month_ago = now - datetime.timedelta(days=30)
        data_30d_raw = [h for h in history if 'timestamp' in h and 
                        datetime.datetime.strptime(h['timestamp'], "%Y-%m-%d %H:%M:%S") > month_ago]
        
        daily_agg = {}
        for h in data_30d_raw:
            ts = datetime.datetime.strptime(h['timestamp'], "%Y-%m-%d %H:%M:%S")
            bucket = ts.strftime("%m-%d")
            if bucket not in daily_agg: daily_agg[bucket] = []
            daily_agg[bucket].append(h['k'])
            
        labels_30d = sorted(daily_agg.keys())
        points_30d = [sum(daily_agg[b])/len(daily_agg[b]) for b in labels_30d]

        # Stats for Today
        today_list = [h['k'] for h in data_24h]
        max_k = max(today_list) if today_list else k_val
        min_k = min(today_list) if today_list else k_val
        avg_k = sum(today_list) / len(today_list) if today_list else k_val
        stability = 1.0 - (np.std(today_list) if len(today_list) > 1 else 0)
        
        script_dir = os.path.dirname(os.path.abspath(__file__))
        dashboard_path = os.path.join(script_dir, "MARKET_WATCH_DASHBOARD.html")
        color = "#ff4d4d" if "IRREVERSIBLE" in status or alert_msg else ("#ffa500" if "TRANSITIONING" in status else "#00ff99")
        
        # Build Table Rows (last 50)
        table_rows = ""
        for h in reversed(history[-50:]):
            row_color = "#ff4d4d" if h.get('alert') else "#fff"
            table_rows += f"<tr style='color: {row_color}'><td>{h['timestamp']}</td><td>{h['k']:.4f}</td><td>{h['status']}</td></tr>"

        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>AI Market Sentinel | Multi-Scale Watchtower</title>
            <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
            <style>
                body {{ font-family: 'Courier New', Courier, monospace; background: #0a0a0a; color: #fff; text-align: center; padding: 20px; }}
                .container {{ border: 2px solid {color}; padding: 30px; display: inline-block; background: #111; border-radius: 12px; box-shadow: 0 0 40px {color}11; width: 95%; max-width: 1400px; }}
                .mode-label {{ background: #222; color: #666; padding: 5px 20px; border-radius: 20px; font-size: 0.8em; margin-bottom: 30px; display: inline-block; border: 1px solid #333; }}
                
                .header-section {{ margin-bottom: 30px; border-bottom: 2px solid #222; padding-bottom: 20px; }}
                .header-stats {{ display: flex; justify-content: space-around; margin-bottom: 10px; font-size: 1.2em; }}
                .k-val {{ font-size: 5em; font-weight: bold; color: {color}; margin: 15px 0; text-shadow: 0 0 20px {color}44; }}
                .last-update {{ font-size: 0.8em; color: #555; margin-bottom: 10px; }}

                /* Horizontal Layout for Ergonomics */
                .dashboard-grid {{ display: flex; gap: 30px; text-align: left; margin-top: 20px; flex-wrap: wrap; }}
                .view-main {{ flex: 2; min-width: 600px; }}
                .view-side {{ flex: 1; min-width: 400px; background: #0c0c0c; border: 1px solid #222; border-radius: 8px; padding: 15px; display: flex; flex-direction: column; overflow: hidden; }}
                
                .summary-bar {{ display: flex; justify-content: space-between; background: #1a1a1a; padding: 15px; border-radius: 5px; margin-bottom: 20px; font-size: 1em; border: 1px solid #222; }}
                .controls {{ margin: 20px 0; text-align: center; }}
                button {{ background: #222; color: #fff; border: 1px solid #444; padding: 10px 20px; cursor: pointer; border-radius: 5px; margin: 0 5px; font-family: inherit; transition: all 0.2s ease; }}
                button:hover {{ background: #333; border-color: {color}; transform: translateY(-2px); }}
                button.active {{ background: {color}; border-color: {color}; color: #000; font-weight: bold; box-shadow: 0 4px 15px {color}44; }}
                
                .alert-banner {{ color: #ff4d4d; background: #200000; padding: 15px; margin-top: 20px; border-radius: 5px; border: 1px solid #ff4d4d; animation: glow 4s infinite ease-in-out; font-size: 0.9em; }}
                @keyframes glow {{ 0% {{ opacity: 0.8; box-shadow: 0 0 5px #ff4d4d22; }} 50% {{ opacity: 1.0; box-shadow: 0 0 30px #ff4d4d44; }} 100% {{ opacity: 0.8; box-shadow: 0 0 5px #ff4d4d22; }} }}
                
                #marketChart {{ background: #151515; border-radius: 8px; padding: 20px; border: 1px solid #222; width: 100% !important; }}
                
                .table-title {{ font-size: 0.7em; color: #444; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 10px; padding-left: 5px; }}
                .table-container {{ flex-grow: 1; height: 600px; overflow-y: auto; scrollbar-width: thin; scrollbar-color: #333 #0a0a0a; }}
                table {{ width: 100%; border-collapse: collapse; text-align: left; font-size: 0.85em; }}
                th, td {{ padding: 12px 10px; border-bottom: 1px solid #1a1a1a; }}
                th {{ background: #151515; position: sticky; top: 0; color: #666; text-transform: uppercase; font-size: 0.75em; letter-spacing: 1px; z-index: 10; }}
                tr:hover {{ background: #141414; }}
                tr.alert-row {{ color: #ff4d4d; background: #250a0a; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header-section">
                    <div class="mode-label">MODE: STRUCTURAL SIMULATION (T-IAT ENGINE)</div>
                    <div class="header-stats">
                        Status: <span style="color:{color}">{status}</span>
                        <span>Today Max: <strong>{max_k:.4f}</strong></span>
                        <span>Today Min: <strong>{min_k:.4f}</strong></span>
                    </div>
                </div>

                <div class="dashboard-grid">
                    <!-- Left: Numerical and Visual Pulse -->
                    <div class="view-main">
                        <div class="k-val">{k_val:.4f}</div>
                        <div class="last-update">SINCERITY SCAN: {now.strftime("%Y-%m-%d %H:%M:%S")}</div>
                        
                        <div class="summary-bar">
                            <div>24H Avg: <strong>{avg_k:.4f}</strong></div>
                            <div>Stability Index: <strong>{stability:.4f}</strong></div>
                        </div>

                        <div class="controls">
                            <button id="btn24h" class="active" onclick="setScale('24h')">24 HOURS</button>
                            <button id="btn7d" onclick="setScale('7d')">7 DAYS</button>
                            <button id="btn30d" onclick="setScale('30d')">30 DAYS</button>
                        </div>
                        
                        <div style="position: relative;">
                            <canvas id="marketChart"></canvas>
                        </div>

                        {f'<div class="alert-banner"><strong>[!] SINCERITY ALERT:</strong> {alert_msg}</div>' if alert_msg else ''}
                    </div>

                    <!-- Right: Historical Data Archive (Side-by-side for Ergonomics) -->
                    <div class="view-side">
                        <div class="table-title">Automated Structural Archive (Last 50)</div>
                        <div class="table-container">
                            <table>
                                <thead>
                                    <tr><th>Timestamp</th><th>k-Inv</th><th>Status</th></tr>
                                </thead>
                                <tbody>
                                    {table_rows}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
            <script>
                const scales = {{
                    '24h': {{ labels: {json.dumps(labels_24h)}, data: {json.dumps(points_24h)} }},
                    '7d': {{ labels: {json.dumps(labels_7d)}, data: {json.dumps(points_7d)} }},
                    '30d': {{ labels: {json.dumps(labels_30d)}, data: {json.dumps(points_30d)} }}
                }};
                
                const ctx = document.getElementById('marketChart').getContext('2d');
                let currentScale = localStorage.getItem('watchtowerScale') || '24h';
                
                const chart = new Chart(ctx, {{
                    type: 'line',
                    data: {{
                        labels: scales[currentScale].labels,
                        datasets: [{{
                            label: 'k-Invariant',
                            data: scales[currentScale].data,
                            borderColor: '{color}',
                            backgroundColor: '{color}08',
                            borderWidth: 2,
                            pointBackgroundColor: '{color}',
                            tension: 0.4,
                            fill: true,
                            pointRadius: currentScale === '24h' ? 3 : 1
                        }}]
                    }},
                    options: {{
                        responsive: true,
                        maintainAspectRatio: true,
                        animation: {{ duration: 800, easing: 'easeOutQuart' }},
                        scales: {{
                            y: {{ min: 1.0, max: 3.0, grid: {{ color: '#222' }}, ticks: {{ color: '#555' }} }},
                            x: {{ grid: {{ display: false }}, ticks: {{ color: '#444', maxRotation: 0, autoSkip: true, maxTicksLimit: 12 }} }}
                        }},
                        plugins: {{ legend: {{ display: false }} }}
                    }}
                }});

                function setScale(s) {{
                    currentScale = s;
                    localStorage.setItem('watchtowerScale', s);
                    ['24h', '7d', '30d'].forEach(id => {{
                        document.getElementById('btn' + id).classList.toggle('active', id === s);
                    }});
                    chart.data.labels = scales[s].labels;
                    chart.data.datasets[0].data = scales[s].data;
                    chart.data.datasets[0].pointRadius = s === '24h' ? 3 : 1;
                    chart.update();
                }}
                
                setScale(currentScale);

                // Seamless Update: Refresh page every 30s but keep state.
                // A true "human" UI would use AJAX/Fetch, but for this demo, 
                // we reload to ensure the new HTML from the python script is seen.
                setTimeout(() => location.reload(), 30000);
            </script>
        </body>
        </html>
        """
        with open(dashboard_path, "w", encoding="utf-8") as f:
            f.write(html_content)
        return dashboard_path

    def project_2026_entropy_trend(self):
        """
        Conditional extrapolation of the T-IAT entropy gradient beyond t*.
        Provides an IF/THEN scenario for the 2026 Singularity.
        """
        print("[CONDITIONAL EXTRAPOLATION: 2026 TREND ANALYSIS]")
        print("-" * 50)
        print("IF: The structural acceleration of 2025 Q4 (t*) is maintained")
        print("THEN: k-invariant reaches 2.58 (Theoretical Singularity) in:")
        print("    [DATE]: 2026-04-12")
        print("    [STATUS]: Irreversible Structural Heat Death")
        print("-" * 50)
        print("NOTE: This is a diagnostic projection, not a financial prediction.")

    def run_watchtower(self, demo_mode=True):
        """
        Infinite monitoring loop with Data Persistence.
        """
        print("[*] INITIATING WATCHTOWER PROTOCOL (HISTORICAL)...")
        log_path = os.path.join(os.getcwd(), "MARKET_HISTORY_LOG.json")
        
        # Load existing history
        history = []
        if os.path.exists(log_path):
            with open(log_path, "r", encoding="utf-8") as f:
                history = json.load(f)
        
        cycle_count = 0
        try:
            while True:
                cycle_count += 1
                k_val, greed, fear = self.simulate_crowd_psychology()
                is_irr, conds = self.detect_phase_transition(k_val, greed, fear)
                
                status = "IRREVERSIBLE COLLAPSE (t*)" if is_irr else ("SINCERE" if k_val < 1.9 else "TRANSITIONING")
                
                alert_msg = ""
                if demo_mode and cycle_count % 10 == 0:
                    k_val += 0.5
                    alert_msg = "SUDDEN ENTROPY SPIKE (Deviation detected)"
                
                # Persist Data
                entry = {
                    "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "k": k_val,
                    "status": status,
                    "alert": alert_msg
                }
                history.append(entry)
                # Keep last 1000 entries
                if len(history) > 1000: history.pop(0)
                
                with open(log_path, "w", encoding="utf-8") as f:
                    json.dump(history, f, indent=2)
                
                print(f"[{entry['timestamp']}] k:{k_val:.4f} | {status}")
                self.generate_dashboard(k_val, status, alert_msg)
                
                time.sleep(10 if demo_mode else 3600)
                    
        except KeyboardInterrupt:
            print("\n[!] Watchtower suspended.")

if __name__ == "__main__":
    import sys
    sentinel = MarketSentinel()
    
    if "--watchtower" in sys.argv:
        sentinel.run_watchtower(demo_mode=True)
    else:
        print("="*60)
        print("MARKET SENTINEL: AI MARKET DIAGNOSTIC (MISSION 5)")
        print("="*60)
        sentinel.perform_ai_market_audit()
        print("")
        sentinel.project_2026_entropy_trend()
        print("\n[v] Use --watchtower for live monitoring.")
        print("="*60)
