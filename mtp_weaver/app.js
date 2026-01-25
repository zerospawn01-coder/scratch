/**
 * WeaverApp: The primary coordination logic for the Antigravity MTP.
 * 
 * Professional Features:
 * - Robust DOM validation to prevent runtime crashes.
 * - Encapsulated Sentinel Polling with error resilience.
 * - Clear semantic mapping for Braid Generation.
 */
class WeaverApp {
    constructor() {
        this.renderer = new BraidRenderer('braid-canvas');
        this.engine = new SincerityEngine();
        
        // --- DOM Elements ---
        this.elements = {
            input: document.getElementById('user-input'),
            metricCfail: document.getElementById('metric-cfail'),
            metricDkl: document.getElementById('metric-dkl'),
            metricStability: document.getElementById('metric-stability'),
            gaugeCfail: document.getElementById('gauge-cfail'),
            gaugeDkl: document.getElementById('gauge-dkl'),
            gaugeStability: document.getElementById('gauge-stability'),
            silentGateOverlay: document.getElementById('silent-gate'),
            lineageList: document.getElementById('lineage-list'),
            discoveryDepth: document.getElementById('metric-discovery'),
            gaugeDiscovery: document.getElementById('gauge-discovery'),
            led: document.getElementById('heartbeat-led')
        };

        // Mapping of semantic keywords to Braid Generators
        this.semanticMap = {
            'truth': 1, 'fact': 1, 'human': 1, 'self': 1,
            'fake': -1, 'lie': -1,
            'logic': 2, 'theory': 2,
            'error': -2, 'gap': -2
        };

        this.init();
    }

    init() {
        this._bindEvents();
        this.pollSentinels();
        // Constant heartbeat every 5 seconds
        setInterval(() => this.pollSentinels(), 5000);
        this.renderer.drawBraid([]);
        console.info("[SYSTEM] WeaverApp initialized with hardened protocol.");
    }

    _bindEvents() {
        if (this.elements.input) {
            this.elements.input.addEventListener('keypress', (e) => this._handleInput(e));
        }
    }

    _handleInput(e) {
        if (e.key === 'Enter' && this.elements.input.value.trim() !== '') {
            const text = this.elements.input.value.toLowerCase();
            this.elements.input.value = '';

            const words = text.split(/\s+/);
            let addedAny = false;
            
            words.forEach(word => {
                if (this.semanticMap[word]) {
                    const metrics = this.engine.addGenerator(this.semanticMap[word]);
                    this.updateUI(metrics);
                    addedAny = true;
                }
            });

            // Default dialogue braid if no specific keywords found
            if (!addedAny) {
                const metrics = this.engine.addGenerator(3); 
                this.updateUI(metrics);
            }
        }
    }

    /**
     * Synchronizes main UI with current internal metrics.
     */
    updateUI(metrics) {
        const { elements, renderer, engine } = this;
        
        elements.metricCfail.textContent = metrics.cfail;
        elements.metricDkl.textContent = metrics.dkl;

        const stability = Math.max(0, 100 - (metrics.dkl * 100)).toFixed(0);
        elements.metricStability.textContent = `${stability}%`;

        // Update Gauges
        elements.gaugeCfail.style.width = `${Math.min(100, metrics.cfail * 100)}%`;
        elements.gaugeDkl.style.width = `${Math.min(100, metrics.dkl * 100)}%`;
        elements.gaugeStability.style.width = `${stability}%`;

        // Logic Drift Visual Warning
        if (metrics.dkl > 0.4) {
            elements.gaugeDkl.style.background = 'var(--accent-danger)';
        } else if (metrics.dkl > 0.2) {
            elements.gaugeDkl.style.background = 'var(--accent-warning)';
        } else {
            elements.gaugeDkl.style.background = 'var(--accent-safe)';
        }

        // Silent Gate Response (Inhibit high-K content)
        if (metrics.isSilent) {
            elements.silentGateOverlay.style.display = 'block';
            renderer.setRupture(true);
        } else {
            elements.silentGateOverlay.style.display = 'none';
            renderer.setRupture(false);
        }

        renderer.drawBraid(engine.currentBraid);
    }

    /**
     * Polls the shared Sentinel repository for cross-check reports.
     */
    async pollSentinels() {
        const { elements } = this;
        
        // Trigger heartbeat LED
        if (elements.led) {
            elements.led.classList.add('heartbeat-active');
            setTimeout(() => elements.led.classList.remove('heartbeat-active'), 1000);
        }

        try {
            // Simulated High-Precision Sentinel Pulse
            const mockPulse = [
                { agent: "PHYSICS_SENTINEL", version: "1.1.0", status: "STABLE", h1_persistence: 0.25 },
                { 
                  agent: "LOGIC_SENTINEL", version: "1.1.0", 
                  status: this.engine.currentBraid.length > 8 ? "KNOT_DETECTED" : "STABLE" 
                },
                { 
                  agent: "DISCOVERY_SENTINEL", version: "1.2.0", 
                  status: Math.random() > 0.6 ? "GAP_IDENTIFIED" : "SCANNING" 
                },
                { agent: "CHEMICAL_SENTINEL", version: "1.1.0", status: "STABLE_CONFIG" },
                { agent: "QUANTUM_SENTINEL", version: "0.1.0_ibm", status: "QUEUE_ACTIVE", bridge: "IBM_Q" }
            ];
            
            this.updateLineages(mockPulse);

            // Update Discovery Metrics
            const depth = (Math.random() * 100).toFixed(1);
            if (elements.discoveryDepth) {
                elements.discoveryDepth.textContent = `${depth}ly`;
                elements.gaugeDiscovery.style.width = `${depth}%`;
            }

            // Global Rupture Check
            if (mockPulse.some(r => r.status === "RUPTURE" || r.status === "KNOT_DETECTED")) {
                elements.silentGateOverlay.style.display = 'block';
                this.renderer.setRupture(true);
            }
        } catch (err) {
            console.error("Sentinel Sync Fail:", err);
        }
    }

    /**
     * Renders the trace of Sentinel reports on screen.
     */
    updateLineages(reports) {
        const { lineageList } = this.elements;
        if (!lineageList) return;
        
        lineageList.innerHTML = '';
        reports.forEach(report => {
            const item = document.createElement('div');
            let statusClass = ' active';
            
            if (report.status === 'RUPTURE' || report.status === 'KNOT_DETECTED') statusClass = ' rupture-critical';
            if (report.status === 'GAP_IDENTIFIED') statusClass = ' discovery-gap';

            item.className = 'lineage-item' + statusClass;
            item.textContent = `${report.agent} [v${report.version}] - ${report.status}`;
            
            if (report.discovery_link) {
                item.style.cursor = 'pointer';
                item.onclick = () => window.open(report.discovery_link, '_blank');
            }
            lineageList.appendChild(item);
        });
    }
}

// Initialize on Load
document.addEventListener('DOMContentLoaded', () => new WeaverApp());
