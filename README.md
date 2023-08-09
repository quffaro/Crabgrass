# Crabgrass

Crabgrass is an agent-based model (ABM) written during an introductory course in Mathematical Oncology at Moffitt. The purpose of this simulation was to familiarize myself with both the Julia ecosystem and agent-based modeling of interactions where environmental toxicity was a product of agent interactions.

Here, Crabs are motile herbivores which prey on Grass, sessile autotrophs with a defense mechanism that releases a toxin into the immediate area. This repels Crabs but also inhibits Grass reproduction temporarily. The third agent, Fungus, is sessile and consumes toxins in the soil. Previous implementations of Crabgrass did not immediately remove dead Crabs but considered them "dead" for the purposes of fungi to decompose them as another food source.


