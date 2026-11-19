# chapter-faust — 浮士德第一集

*Faust: The Knock* is a 3–5 minute, thirty-shot Chinese Faust adaptation with captions and an instrumental score. The production art path is modeled, lit, and assembled in Godot 4. The SVGs under `assets/fallback/` are storyboard plates only; they are byte-identical copies of the adopted `libfaust` assets.

## Art and shot authoring
Open `scenes/episode_001_study.tscn` in Godot to inspect the study. Its `@tool` script, `scripts/episode_001_study.gd`, builds the low-poly room, desk, books, candle, Faust, key, and threshold from Godot primitives and materials. Edit the scene for the main group transforms and the script for the generated geometry and lighting. The brass key is also modeled in Godot; the external candidate key is not used.

`story/episodes/episode-001.json` selects the Godot scene with `godot_scene`. Each shot's `godot_3d` block gives the action beat, camera and look-at endpoints (`[x, y, z]` in scene coordinates), and vertical FOV in degrees. The `asset` and 2D pan/zoom fields are for the storyboard. Shot durations, transitions, captions, and music cues are shared between both paths.

## Short-drama pacing
The first shot must show a supernatural action by 5 seconds, even with sound off. The cold open starts on the brass key: it lifts and spins from 0.5 seconds, reaches its highest point at 2.0, and settles at 3.5. At 4.0 seconds the shot changes to Faust's reaction. The storyboard keeps its adopted plates and animates a drawn key with the same timing.

Keep the camera moving through each native shot and give each shot a distinct action. The camera tracks the key, pushes toward the shadow, and recoils with each knock; candlelight and object motion continue through the longer beats. Each interior shot change uses a 0.5-second diagonal crimson wipe, split evenly across the outgoing and incoming shots. No opening wipe delays the hook. Hook timing is in the first shot's `hook` block; `pacing` sets the deadline and wipe duration. Keep the hook peak at or before the deadline, let it settle before the first wipe, and keep shot and music timing aligned to the 24 fps, 180-second timeline. Both smoke modes check hook timing and wipe continuity; the 3D smoke test also checks the key's actual lift and return.

## Godot prerequisite
Verified `4.3.stable.official.77dcf97d8`, installed without sudo from the [official 4.3 Linux x86-64 release](https://github.com/godotengine/godot/releases/tag/4.3-stable). Binary: `/home/donz/.local/opt/godot-4.3/Godot_v4.3-stable_linux.x86_64`; entry point: `/home/donz/.local/bin/godot`. An X11-compatible display is required for rendering (XWayland works); import and smoke tests can run headless.

## Preview and export
```bash
python3 ../faust-mv/tools/faust_mv.py validate --root .
godot --headless --editor --path . --import
godot --headless --path . -- --smoke --require-3d
godot --headless --path . -- --smoke --storyboard
godot --editor --path .
godot --path .
godot --path . -- --storyboard
python3 tools/export_episode.py
python3 tools/export_episode.py --mode storyboard
python3 tools/validate_media.py
```

Preview defaults to 3D and switches to the shot's storyboard asset when the scene or a shot pose is unavailable. Space pauses, Left/Right jump shots, and S toggles the safe area. The fallback player supports image plates, frame lists, and Godot-native Ogg Theora (`.ogv`) clips; this episode uses the SVG plates.

Export defaults to 3D and fails if a shot cannot use the native scene. `--mode storyboard` explicitly selects the fallback and writes `episode-001.storyboard.mp4` and its own validation report, so it cannot overwrite the 3D output. Godot Movie Maker renders the timeline and captions at 540x960 and 24 fps. FFmpeg upscales to 1080x1920, muxes the authored WAV, and the validator checks the result before the exporter publishes it under `exports/`. Use `--out-dir` for a separate destination and `--godot` to select another installation. The sibling `faust-mv` / `libfaust` check still validates story timing and fallback provenance; neither supplies the native 3D meshes.

Existing `exports/` previews may predate the pacing update. Rerun the exporter to render the current cut and its matching validation report.

`tools/generate_music.py` can regenerate the checked-in WAV. Before publication, review story readability, caption placement, continuity, music, and rights in a full playback.
