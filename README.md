# The Nuclear Life Simulator - Java v2.0

Complete rewrite and overhaul of the original Processing-based evolutionary artificial life simulator by Christopher J Boardman.

## Features (Overhauled)

- **Pure Java 21** — no Processing, no external JARs required. Uses only the JDK (Swing + Java Sound).
- **Neural Network Brains** — 6-6-4 MLP with tanh + sigmoid. Weights are heritable, recombined on sexual reproduction, and mutated. Radiation increases mutation pressure.
- **Environmental Pressures** — Oxygen, CO2, Sulfur Dioxide + global Radiation dynamically affect organism energy drain and survival. Organisms evolve tolerance traits.
- **Hard Population Cap** — 280 max. Weakest individuals are culled when exceeded.
- **Generation Tracking** — Max generation displayed. Offspring inherit + mutate from parents (asexual budding or sexual).
- **Mutation Pools** — Radioactive zones that accelerate mutation for organisms inside them.
- **Poop & Nutrient Cycle** — Eating produces poop that slowly decays and emits SO2.
- **Full Camera** — Drag to pan the 4000x4000 world, mouse wheel to zoom (0.28x–4.2x).
- **Creature Selection** — Click organisms to inspect their generation, energy, and evolved tolerances.
- **Multiple UI States** — Main menu, world parameter sliders + presets (Balanced / Radioactive / Lush / Toxic Wastes), loading, simulation, description, credits, settings.
- **"Empty World" Start** — Special preset with zero initial population in a harsh environment (evolution from nothing is hard but possible via the pools).
- **Audio** — 4 original tracks with seamless looping and master volume control.
- **Settings** — Volume, quick window size presets, maximized toggle, keybindings help.
- **Keyboard & Mouse Controls** (see in-game or Settings):
  - Drag: pan
  - Wheel: zoom
  - Click: select creature
  - SPACE: pause/resume
  - R: restart
  - N: next track
  - +/-: speed
  - ESC: back to menu

## Requirements

- Java 21+ (Temurin / Adoptium recommended). The project was developed with Eclipse Temurin 21.

## How to Build & Run (Windows)

### Option 1: Using the provided helper (recommended)

1. Double-click `run.bat` (create it if you deleted it — see below).

### Option 2: Manual

Open PowerShell or CMD in this folder:

```powershell
javac NuclearLifeSimulator.java
java NuclearLifeSimulator
```

On first run it may take a second to compile.

### Creating run.bat (if missing)

```bat
@echo off
echo Compiling The Nuclear Life Simulator...
javac NuclearLifeSimulator.java
if errorlevel 1 (
  echo Compilation failed.
  pause
  exit /b 1
)
echo Running...
java NuclearLifeSimulator
pause
```

## Controls in Simulation

- Mouse drag = pan camera
- Mouse wheel = zoom
- Left click on creature = select + show stats
- SPACE = pause/resume
- R = restart
- N = next music track
- + / - = change simulation speed
- ESC = return to main menu

## Known Original Issues Addressed

- Generation counter now works and is the max generation reached.
- Simulation controls and stats only appear during simulation.
- Empty world preset available directly from main menu.
- Reproduction has hard cap + improved sexual/asexual logic + cooldown feel via desire accumulator.
- Neural nets are fully heritable (copied + recombined + mutated) and evolve under environmental selection.
- Settings screen with volume, resolution helpers, and key map.
- Version is prominently displayed.
- Buttons are standard Swing (reliable click targets).

## Project Structure

```
The-Nuclear-Life-Simulator-Java/
├── NuclearLifeSimulator.java   # Everything (monolithic for easy single-file compile/run)
├── audio/
│   ├── track1.wav
│   ├── track2.wav
│   ├── track3.wav
│   ├── track4.wav
├── README.md
├── LICENSE
└── .gitignore
```

All source is in a single `.java` for trivial build while still being cleanly organized with inner classes.

## License

Original and this rewrite are released into the public domain under the Unlicense (see LICENSE file).

## Credits

- Original concept, design, Processing prototype, and music direction: Christopher J Boardman
- Music: Jake Rae & Christopher J Boardman
- Java 2026 rewrite & evolution mechanics overhaul: Grok (xAI) with user direction

Enjoy watching life claw its way back from the ashes.


## UI Refresh (2026 overhaul)
- Fixed: fonts now visible on buttons (explicit dark bg + borders + hover + UIManager overrides for L&F).
- Redone layouts: top toolbar (stats+controls), east side inspector (selected + env), bottom live graphs area.
- Added population graphs etc: live scrolling time-series for Pop/Gen (top chart) and O2/CO2/SO2/Rad (bottom). Custom 2D, throttled history (no extra deps). Clears on restart. Helps see evolution and pressures.

Run via EXE on Desktop or run.bat here for dev.
