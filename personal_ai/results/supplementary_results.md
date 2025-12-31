# Supplementary Results: Instantiation in Artificial Systems

To demonstrate the functional utility of the $K \approx 1.8$ threshold, we instantiated it as a scoring constraint in a simulated token selection task. Given a probability distribution $P(y)$ over a vocabulary, we compared standard 'Argmax' selection against the '1.8 Resonator', which selects tokens minimizing the score function $S(y) = P(y) - 1.8 \cdot I(y)$, where $I(y) = -\log P(y)$.

Quantitative analysis across $N=100$ independent trials (Supplementary Table S1) reveals that the 1.8 Resonator consistently selects tokens with significantly higher information content (mean surprisal $6.15 \pm 0.29$ vs. $1.73 \pm 0.55$ for Argmax; Fig. S4A). Despite this 'leap' in information, selected tokens remain within the top density of the distribution (within Top-50), maintaining grammatical plausibility while entirely avoiding the highest-probability clichés (Cliché Rate = 0.0%).

> **Interpretation:** These results demonstrate that a decision threshold emerging from evolutionary dynamics in biological systems can act as a functional constraint in artificial generative processes, balancing statistical commonality with information gain.
