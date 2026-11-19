extends Node2D

const FRAME_SIZE := Vector2(540, 960)
var episode: Dictionary = {}
var assets: Dictionary = {}
var textures: Dictionary = {}
var video := VideoStreamPlayer.new()
var music := AudioStreamPlayer.new()
var elapsed := 0.0
var shot_start := 0.0
var shot_index := 0
var movie := false
var smoke := false
var paused := false
var safe := false
var current_video := ""
var stage: Node3D
var active_scene := "study"
var use_3d := false
var visual_mode := "auto"
var written_frame := -1
var movie_fps := 24.0
var episode_duration := 0.0
var wipe_duration := 0.0
var hook_pose := Vector2.ZERO
var ui_font: Font
var caption_font_size := 29
var caption_line_spacing := 35

func read_data(path: String) -> Dictionary:
 var file := FileAccess.open(path, FileAccess.READ)
 if not file: return {}
 var result: Variant = JSON.parse_string(file.get_as_text())
 return result if result is Dictionary else {}

func _ready() -> void:
 ui_font = load("res://assets/fonts/DroidSansFallbackFull.ttf") as Font
 var args := OS.get_cmdline_user_args()
 movie = args.has("--render")
 smoke = args.has("--smoke")
 if args.has("--storyboard"): visual_mode = "storyboard"
 elif args.has("--require-3d") or movie: visual_mode = "3d"
 var selection := read_data("res://story/manifest.json")
 episode = read_data("res://" + str(selection.get("episode", "")))
 add_child(video)
 video.size = Vector2(540, 960)
 video.expand = true
 video.volume_db = -80.0
 video.show_behind_parent = true
 add_child(music)
 for asset in read_data("res://assets/manifest.json").get("assets", []):
  assets[asset.asset_id] = asset
 if episode.get("shots", []).is_empty():
  push_error("Episode has no playable shots")
  set_process(false)
  get_tree().quit(1)
  return
 episode_duration = total_duration()
 movie_fps = float(episode.format.fps)
 var transition: Dictionary = episode.get("pacing", {}).get("transition", {})
 if transition.get("effect") == "crimson_wipe":
  wipe_duration = float(transition.get("duration_seconds", 0))
 if visual_mode != "storyboard":
  var path := str(episode.get("godot_scene", ""))
  if not path.is_empty() and ResourceLoader.exists(path, "PackedScene"):
   var packed := load(path) as PackedScene
   if packed and packed.can_instantiate():
    var candidate := packed.instantiate()
    if candidate is Node3D and candidate.has_method("supports") and candidate.has_method("pose"):
     stage = candidate
     add_child(stage)
    else: candidate.free()
 if visual_mode == "3d":
  for shot in episode.shots:
   if not shot_has_3d(shot):
    push_error("Missing Godot 3D scene or pose for " + str(shot.id))
    set_process(false)
    get_tree().quit(1)
    return
 if not movie:
  music.stream = load(episode.audio) if ResourceLoader.exists(episode.audio) else null
  if not music.stream: push_error("Missing soundtrack: " + episode.audio)
  elif not smoke: music.play()
 if smoke:
  var cursor := 0.0
  var failed := not smoke_pacing() or not is_instance_valid(music.stream)
  for i in episode.shots.size():
   var shot: Dictionary = episode.shots[i]
   for fraction in [0.0, 0.5, 0.99]:
    seek(cursor + float(shot.duration) * fraction)
    if shot_index != i: failed = true
    if not use_3d:
     var asset: Dictionary = assets.get(shot.asset, {})
     var frames: Array = asset.get("frames", [])
     if not frames.is_empty():
      for path in frames:
       if not get_texture(path): failed = true
     elif asset.get("kind") == "2d":
      if not get_texture(asset.path): failed = true
     elif not video.stream: failed = true
   print("PREVIEW ", shot.id, " at ", cursor, "s; cue=", shot.cue, "; art=", "3d" if use_3d else "storyboard")
   cursor += float(shot.duration)
  get_tree().quit(int(failed))
  return
 seek(0.0)

func _exit_tree() -> void:
 video.stop()
 video.stream = null
 music.stop()
 music.stream = null
 textures.clear()

func get_texture(path: String) -> Texture2D:
 if not textures.has(path):
  textures[path] = load(path) if ResourceLoader.exists(path) else null
 return textures[path]

func _unhandled_key_input(event: InputEvent) -> void:
 if movie or not event.is_pressed() or event.is_echo(): return
 if event.keycode == KEY_SPACE:
  paused = not paused
  music.stream_paused = paused
  video.paused = paused
 elif event.keycode == KEY_S:
  safe = not safe
 elif event.keycode in [KEY_LEFT, KEY_RIGHT]:
  var target := shot_index + (1 if event.keycode == KEY_RIGHT else -1)
  target = posmod(target, episode.shots.size())
  var cursor := 0.0
  for i in target: cursor += float(episode.shots[i].duration)
  if target > 0: cursor += wipe_duration / 2.0
  seek(cursor)
  if music.stream: music.seek(cursor)
 queue_redraw()

func _process(delta: float) -> void:
 if episode.is_empty() or paused or smoke: return
 if movie:
  written_frame += 1
  var time := float(written_frame) / movie_fps
  if time < episode_duration: seek(time)
  return
 var next := elapsed + delta
 if music.playing: next = music.get_playback_position()
 if next >= episode_duration:
  next = 0.0
  if music.stream: music.play()
 seek(next)

func seek(time: float) -> void:
 elapsed = time
 var cursor := 0.0
 for i in episode.shots.size():
  var duration := float(episode.shots[i].duration)
  if time < cursor + duration:
   shot_index = i
   shot_start = cursor
   break
  cursor += duration
 var shot: Dictionary = episode.shots[shot_index]
 var local_time := elapsed - shot_start
 if is_instance_valid(stage) and stage.has_method("set_scene"):
  stage.set_scene(str(shot.get("scene", "study")))
 hook_pose = sample_hook(shot.get("hook", {}), local_time)
 use_3d = shot_has_3d(shot)
 if is_instance_valid(stage):
  stage.visible = use_3d
  if use_3d:
   stage.pose(shot.godot_3d, local_time / float(shot.duration), elapsed, hook_pose.x, hook_pose.y)
 var asset: Dictionary = {} if use_3d else assets.get(shot.asset, {})
 var path := str(asset.get("path", "")) if asset.get("kind") == "video" else ""
 if path != current_video:
  current_video = path
  video.stop()
  video.stream = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
  if video.stream: video.play()
 queue_redraw()

func shot_has_3d(shot: Dictionary) -> bool:
 var spec: Variant = shot.get("godot_3d")
 return is_instance_valid(stage) and spec is Dictionary and stage.supports(spec)

func total_duration() -> float:
 var value := 0.0
 for shot in episode.get("shots", []): value += float(shot.duration)
 return value

func sample_hook(hook: Dictionary, local_time: float) -> Vector2:
 if hook.get("effect") != "levitating_key": return Vector2.ZERO
 var start := float(hook.start_seconds)
 var peak := float(hook.peak_seconds)
 var settle := float(hook.settle_seconds)
 var lift := smoothstep(start, peak, local_time) * (1.0 - smoothstep(peak, settle, local_time))
 return Vector2(lift, smoothstep(start, settle, local_time))

func wipe_progress(local_time: float, duration: float, index: int) -> float:
 var half := wipe_duration / 2.0
 if half <= 0.0: return -1.0
 if index > 0 and local_time < half: return 0.5 + 0.5 * local_time / half
 if index < episode.shots.size() - 1 and local_time > duration - half:
  return 0.5 * (local_time - duration + half) / half
 return -1.0

func smoke_pacing() -> bool:
 if not episode.has("pacing"): return true
 var first: Dictionary = episode.shots[0]
 var hook: Dictionary = first.get("hook", {})
 var start := float(hook.get("start_seconds", -1))
 var peak := float(hook.get("peak_seconds", -1))
 var settle := float(hook.get("settle_seconds", -1))
 var deadline := float(episode.pacing.get("hook_deadline_seconds", -1))
 var valid: bool = hook.get("effect") == "levitating_key" and 0.0 <= start and start < peak and peak < settle
 valid = valid and peak <= deadline and deadline <= 5.0 and settle < float(first.duration) - wipe_duration / 2.0
 valid = valid and wipe_duration * movie_fps >= 2.0
 for i in episode.shots.size():
  var duration := float(episode.shots[i].duration)
  valid = valid and wipe_duration < duration
  if i < episode.shots.size() - 1:
   valid = valid and is_equal_approx(wipe_progress(duration, duration, i), 0.5)
   valid = valid and is_equal_approx(wipe_progress(0.0, duration, i + 1), 0.5)
 if valid:
  seek(start)
  var at_rest := hook_pose.x
  var native_key: Node3D
  var rest_height := 0.0
  if use_3d:
   native_key = stage.get_node_or_null("Desk/BrassKey") as Node3D
   if native_key: rest_height = native_key.position.y
   valid = is_instance_valid(native_key) and native_key.visible
  seek(peak)
  valid = valid and is_zero_approx(at_rest) and is_equal_approx(hook_pose.x, 1.0)
  if use_3d: valid = valid and is_instance_valid(native_key) and native_key.position.y > rest_height + 0.4
  seek(settle)
  valid = valid and is_zero_approx(hook_pose.x)
  if use_3d: valid = valid and is_instance_valid(native_key) and is_equal_approx(native_key.position.y, rest_height)
 if not valid: push_error("Invalid opening hook or shot transition in episode pacing")
 else: print("PACING hook starts at ", start, "s, peaks at ", peak, "s; wipes ", wipe_duration, "s")
 return valid

func _draw() -> void:
 if episode.get("shots", []).is_empty(): return
 var shot: Dictionary = episode.shots[shot_index]
 if not use_3d:
  draw_storyboard(shot)
  if shot.get("hook", {}).get("effect") == "levitating_key": draw_storyboard_key()
 draw_overlay(shot)

func draw_storyboard(shot: Dictionary) -> void:
 var asset: Dictionary = assets.get(shot.asset, {})
 var progress := clampf((elapsed - shot_start) / float(shot.duration), 0.0, 1.0)
 var texture: Texture2D
 if asset.get("kind") == "2d": texture = get_texture(asset.path)
 var frames: Array = asset.get("frames", [])
 if not frames.is_empty():
  texture = get_texture(frames[int((elapsed - shot_start) * float(asset.get("fps", 24))) % frames.size()])
 var zoom := lerpf(float(shot.get("zoom_start", 1.0)), float(shot.get("zoom_end", 1.1)), progress)
 var size := FRAME_SIZE * zoom
 var pan := lerpf(float(shot.get("pan_start", 0)), float(shot.get("pan_end", 0)), progress)
 if texture: draw_texture_rect(texture, Rect2((FRAME_SIZE - size) / 2.0 + Vector2(pan, 0), size), false)
 elif not video.stream:
  draw_rect(Rect2(0, 0, 540, 960), Color("23151b"))
  draw_string(ui_font if ui_font else ThemeDB.fallback_font, Vector2(36, 480), "Missing: " + str(shot.asset), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func draw_storyboard_key() -> void:
 var lift := hook_pose.x
 var key_center := Vector2(273 - 38 * lift, 610 - 180 * lift)
 draw_circle(key_center, 56 + 22 * lift, Color(0.92, 0.38, 0.16, 0.08 + 0.14 * lift), true, -1.0, true)
 draw_set_transform(key_center, -0.18 + TAU * hook_pose.y, Vector2.ONE * (1.0 + 0.3 * lift))
 var brass := Color("ffcb7f")
 draw_arc(Vector2(-33, 0), 18, 0.0, TAU, 32, brass, 6, true)
 draw_line(Vector2(-15, 0), Vector2(47, 0), brass, 6, true)
 draw_polyline(PackedVector2Array([Vector2(32, 0), Vector2(32, 13), Vector2(47, 13), Vector2(47, 0)]), brass, 6, true)
 draw_set_transform(Vector2.ZERO)

func draw_wipe(progress: float) -> void:
 if progress < 0.0: return
 # The opaque panel covers the camera/plate change at the shot boundary.
 var band := FRAME_SIZE.x + 240.0
 var x := lerpf(-band - 120.0, FRAME_SIZE.x + 120.0, smoothstep(0.0, 1.0, progress))
 var corners := PackedVector2Array([Vector2(x, 0), Vector2(x + band, 0),
   Vector2(x + band - 120, FRAME_SIZE.y), Vector2(x - 120, FRAME_SIZE.y)])
 draw_colored_polygon(corners, Color("631c36"))
 draw_line(corners[0], corners[3], Color("b53852"), 10, true)
 draw_line(corners[1], corners[2], Color("f46a68"), 8, true)

func draw_overlay(shot: Dictionary) -> void:
 var fade := float(shot.get("fade_in", 0))
 if fade > 0.0: draw_rect(Rect2(0, 0, 540, 960), Color(0, 0, 0, 0.85 * (1.0 - clampf((elapsed - shot_start) / fade, 0.0, 1.0))))
 var lines: PackedStringArray = str(shot.caption).split("\n", false)
 for i in lines.size():
  var position := Vector2(45, 760 + caption_line_spacing * i)
  draw_string(ui_font if ui_font else ThemeDB.fallback_font, position, lines[i], HORIZONTAL_ALIGNMENT_CENTER, 450, caption_font_size, Color("fff8ef"))
 draw_wipe(wipe_progress(elapsed - shot_start, float(shot.duration), shot_index))
 if not movie:
  if safe: draw_rect(Rect2(35, 60, 470, 820), Color("e7c9a0"), false, 1)
  draw_string(ui_font if ui_font else ThemeDB.fallback_font, Vector2(35, 925), "镜头 %s / %s   %.1f秒" % [shot.id.trim_prefix("shot-"), shot.cue, elapsed], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e7c9a0"))
