class BraidRenderer {
    constructor(svgElementId) {
        this.svg = document.getElementById(svgElementId);
        this.strands = 3; // Default n=3
        this.colors = ['#00ffcc', '#00ccff', '#cc00ff']; // Precise accents
        this.margin = 50;
        this.segmentHeight = 80;
        this.strandSpacing = 80;
    }

    clear() {
        while (this.svg.firstChild) {
            this.svg.removeChild(this.svg.firstChild);
        }
    }

    drawBraid(word) {
        this.clear();
        let currentY = this.margin;
        const width = this.svg.clientWidth;
        const startX = (width - (this.strands - 1) * this.strandSpacing) / 2;

        // Current positions of strands
        let positions = Array.from({length: this.strands}, (_, i) => startX + i * this.strandSpacing);
        let strandPaths = Array.from({length: this.strands}, (_, i) => `M ${positions[i]} ${currentY}`);

        // Draw initial straight segments
        currentY += 20;
        for (let i = 0; i < this.strands; i++) {
            strandPaths[i] += ` L ${positions[i]} ${currentY}`;
        }

        // Process Braid Word
        word.forEach(gen => {
            const idx = Math.abs(gen) - 1; // 1-indexed generator
            const isInverse = gen < 0;
            const nextY = currentY + this.segmentHeight;

            // Draw all strands that are NOT participating in the crossing
            for (let i = 0; i < this.strands; i++) {
                if (i !== idx && i !== idx + 1) {
                    strandPaths[i] += ` L ${positions[i]} ${nextY}`;
                }
            }

            // Draw Crossing for idx and idx + 1
            const x1 = positions[idx];
            const x2 = positions[idx + 1];
            const cpY = currentY + this.segmentHeight / 2;

            // Simple Bezier for non-participating segments would be straight,
            // but for crossings we use curves.
            
            // To animate "over/under", we draw background first (if needed) 
            // but for thin lines, we use a simple visual gap or opacity.
            
            // Strand idx moves to idx+1
            strandPaths[idx] += ` C ${x1} ${cpY}, ${x2} ${cpY}, ${x2} ${nextY}`;
            // Strand idx+1 moves to idx
            strandPaths[idx+1] += ` C ${x2} ${cpY}, ${x1} ${cpY}, ${x1} ${nextY}`;

            // Update positions
            [positions[idx], positions[idx + 1]] = [positions[idx + 1], positions[idx]];
            currentY = nextY;
        });

        // Final tail segments
        currentY += 20;
        for (let i = 0; i < this.strands; i++) {
            strandPaths[i] += ` L ${positions[i]} ${currentY}`;
        }

        // Render Paths to SVG
        strandPaths.forEach((d, i) => {
            const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
            path.setAttribute("d", d);
            path.setAttribute("stroke", this.colors[i % this.colors.length]);
            path.setAttribute("stroke-width", "1.5");
            path.setAttribute("fill", "none");
            path.setAttribute("stroke-linecap", "round");
            this.svg.appendChild(path);
        });

        // Update SVG height
        this.svg.setAttribute("height", currentY + this.margin);
    }

    setRupture(active) {
        const display = document.getElementById('main-display');
        if (active) {
            display.classList.add('rupture');
        } else {
            display.classList.remove('rupture');
        }
    }
}

window.BraidRenderer = BraidRenderer;
