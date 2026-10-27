---
tags: [rwa-vault, architecture, supervisors]
updated: 2026-10-17
---
# Process and Technical Maps (FigJam)

The supervisor board. **Current board:** https://www.figma.com/board/xtLGPuH60PQ0gNCnUNFVXv ("QORA - Process and Technical Maps")

## Four frames, left to right
| Frame | What it contains |
|---|---|
| **Process Flow** | 3 swimlane blocks: Asset Onboarding, Investment, Lending. Lanes are people, app, platform services and smart contracts; stages run across the top |
| **Technical Flow** | 3 swimlane blocks with runtime lanes (Browser, pq-core Rust library, Node services, Data stores, Arbitrum Sepolia, External/Offline): PQC Signing and Verification, Price Oracle, Anchoring and Proof. Arrows carry real API and component names; "(planned)" marks interfaces not written yet |
| **Modules** | 12 module cards in build order M0 → M11, each with Builds / Needs / Stack / Status rows |
| **Tech Stack** | Layer × Technologies × Purpose, with a header row and a header column |

## Conventions (team requirement, 2026-10-17)
- Every process is its own block: a dark title bar, a top header row of stages, a left header column of lanes, and each lane as its own subsection.
- Standard shapes: start/end = dark terminator; process = square rectangle; decision = diamond; database = cylinder; stream/queue = horizontal cylinder; library or external system = predefined-process box; output = document.
- Titles are one or two words. No sentence headings or taglines.
- Colour marks lanes and layers only: people grey, app blue, services green, data yellow, contracts violet, crypto library orange.
- No mind map (it would repeat Process Flow) and no build-sequence frame.

## Keeping it current
When a module's status changes, update the Status row of its card in **Modules**. When a "(planned)" interface gets written, remove the marker in **Technical Flow**.

## Older boards (archive)
- Overview attempt, 6 frames: https://www.figma.com/board/2beDDFnyAlhTyGJaRJvlEI
- First detailed board: https://www.figma.com/board/byVlBWjhhhw410S92Q9OLW

Related: [[Project Memory]], [[All Modules]], [[Roadmap & Milestones]]
