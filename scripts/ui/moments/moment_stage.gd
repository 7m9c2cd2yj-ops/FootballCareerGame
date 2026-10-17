class_name MomentStage
extends Node3D
## Builds and animates the low-poly 3D set for a key moment: pitch, goal,
## ball, keeper, shooter and (for free kicks) the wall. Display only.
##
## World layout: the goal line is z = 0 with the goal centred on x = 0, the
## pitch runs towards +z. A goal-plane point (x, y) is the world point (x, y, 0).

signal animation_finished

const KEEPER_LINE_Z := 0.4
const KEEPER_HEIGHT := 1.85
const PLAYER_RADIUS := 0.3
const WALL_PLAYERS := 4
const MIN_ANIMATION_TIME := 0.35
const PITCH_COLOR := Color(0.2, 0.55, 0.25)
const LINE_COLOR := Color(0.95, 0.95, 0.95)
const BALL_COLOR := Color(1, 1, 1)
const BOOT_SIZE := Vector3(0.14, 0.1, 0.26)
const CELEBRATION_TIME := 0.9
const CAPSULE_SEGMENTS := 20
const CAPSULE_RINGS := 4
## Shooter stands beside the ball so they do not block the camera.
const SHOOTER_OFFSET := Vector3(-1.6, 0.0, -0.2)
## Camera behind the ball, framing the goal; narrower lens for longer shots.
const SHOT_CAMERA_BACK := 2.5
const SHOT_CAMERA_HEIGHT := 1.6
const SHOT_CAMERA_FOV_AT_PENALTY := 52.0
const MIN_CAMERA_FOV := 28.0
const MAX_CAMERA_FOV := 120.0
## One-on-ones: further back and wider, so the attacker and ball stay in view.
const RUN_CAMERA_BACK := 5.5
const RUN_CAMERA_HEIGHT := 2.4
const RUN_CAMERA_FOV := 50.0
## Aspect ratio the camera angles are designed for (landscape phone).
const DESIGN_ASPECT := 16.0 / 9.0


## Colours (from the accessibility palette) and the player's equipped cosmetics.
class Look:
	extends RefCounted
	var player_kit: Color = Color(0.15, 0.35, 0.85)
	var opponent_kit: Color = Color(0.85, 0.2, 0.2)
	var keeper_kit: Color = Color(0.95, 0.8, 0.1)
	var aim: Color = Color(1.0, 0.85, 0.0)
	var boots: Color = Color(0.1, 0.1, 0.1)
	## A StoreCatalog.CELEBRATION_STYLES value.
	var celebration: String = "jump"


var _look: Look = null
var _tuning: MomentTuning = null
var _spec: MomentSpec = null
var _camera: Camera3D = null
## Vertical field of view at the design (landscape) aspect.
var _design_fov: float = 52.0
var _ball: MeshInstance3D = null
var _keeper: MeshInstance3D = null
var _shooter: MeshInstance3D = null
var _aim_marker: MeshInstance3D = null


func build(spec: MomentSpec, tuning: MomentTuning, look: Look = null) -> void:
	_spec = spec
	_tuning = tuning
	_look = look if look != null else Look.new()
	_add_light()
	_add_pitch()
	_add_goal()
	var keeper_at := Vector3(_keeper_start_x(), KEEPER_HEIGHT / 2, KEEPER_LINE_Z)
	if spec.is_save():
		# The player is the keeper: see-through, so the incoming ball stays visible.
		var ghost := _material(Color(_look.player_kit, 0.35))
		ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_keeper = _add_mesh_with(_capsule_mesh(KEEPER_HEIGHT), ghost, keeper_at)
	else:
		_keeper = _add_capsule(_look.keeper_kit, keeper_at)
	var shooter_kit := _look.opponent_kit if spec.is_save() else _look.player_kit
	var shooter_at := Vector3(0, KEEPER_HEIGHT / 2, spec.distance) + SHOOTER_OFFSET
	_shooter = _add_capsule(shooter_kit, shooter_at)
	_add_boots(_player())
	_ball = _add_ball()
	_aim_marker = _add_aim_marker()
	if spec.moment_type == MomentSpec.FREE_KICK:
		_add_wall()
	_add_camera()


## Converts a touch position to the goal-plane point under it.
func screen_to_goal(screen: Vector2) -> Vector2:
	var origin := _camera.project_ray_origin(screen)
	var direction := _camera.project_ray_normal(screen)
	var hit: Variant = Plane(Vector3.BACK, 0.0).intersects_ray(origin, direction)
	if hit == null:
		return Vector2(0.0, _tuning.value("keeper", "start_height"))
	var point: Vector3 = hit
	return Vector2(point.x, point.y)


func show_aim(point: Vector2) -> void:
	_aim_marker.visible = true
	_aim_marker.position = Vector3(point.x, point.y, 0.05)


func hide_aim() -> void:
	_aim_marker.visible = false


## One-on-one: moves the attacker (with the ball) and the rushing keeper.
func set_run(attacker_distance: float, keeper_out: float) -> void:
	_shooter.position.z = attacker_distance + SHOOTER_OFFSET.z
	_ball.position.z = attacker_distance
	_keeper.position.z = KEEPER_LINE_Z + keeper_out
	_camera.position.z = attacker_distance + RUN_CAMERA_BACK
	_camera.look_at(Vector3(0, 0.3, 0))


## Sends the ball from where it is to `result.ball_target` and the keeper to
## `result.keeper_target`. `bend` curves the flight sideways (free-kick curl).
func play_result(result: MomentResult, duration: float, bend: float) -> void:
	var time := maxf(duration, MIN_ANIMATION_TIME)
	var end := Vector3(result.ball_target.x, result.ball_target.y, 0.0)
	if result.outcome == MomentResult.BLOCKED:
		end.z = _spec.distance - _tuning.value("free_kick", "wall_distance")
	elif result.outcome == MomentResult.MISSED:
		end.z = -1.5
	animate_ball(end, time, bend)
	dive_keeper(result.keeper_target, time)
	get_tree().create_timer(time).timeout.connect(animation_finished.emit)


## Ball along a curved path from its current position to `end`.
func animate_ball(end: Vector3, duration: float, bend: float) -> void:
	var start := _ball.position
	var control := (start + end) / 2.0 + Vector3(bend, 0.4 + start.distance_to(end) * 0.03, 0.0)
	var tween := create_tween()
	tween.tween_method(_place_ball.bind(start, control, end), 0.0, 1.0, duration)


## Keeper dives so their centre ends on the goal-plane point `target`.
func dive_keeper(target: Vector2, duration: float) -> void:
	var shift := target.x - _keeper.position.x
	var lying := clampf(-shift * 0.5, -1.4, 1.4)
	var end := Vector3(target.x, maxf(target.y, PLAYER_RADIUS + 0.1), _keeper.position.z)
	var tween := create_tween().set_parallel()
	tween.tween_property(_keeper, "position", end, duration)
	tween.tween_property(_keeper, "rotation:z", lying, duration)


## The player's equipped celebration after a successful moment (display only).
func celebrate() -> void:
	var player := _player()
	var tween := create_tween()
	var step := CELEBRATION_TIME / 2.0
	match _look.celebration:
		"spin":
			tween.tween_property(
				player, "rotation:y", player.rotation.y + TAU * 2, CELEBRATION_TIME
			)
		"slide":
			var forward := player.position + Vector3(0, -0.5, 2.0)
			tween.tween_property(player, "position", forward, step)
			tween.parallel().tween_property(player, "rotation:x", -0.5, step)
		"bow":
			tween.tween_property(player, "rotation:x", 0.7, step)
			tween.tween_property(player, "rotation:x", 0.0, step)
		_:
			var rest := player.position
			tween.set_loops(2)
			tween.tween_property(player, "position", rest + Vector3(0, 0.8, 0), step / 2)
			tween.tween_property(player, "position", rest, step / 2)


## Save moments: the opponent's run-up to the ball.
func run_up(duration: float) -> void:
	var tween := create_tween()
	var at_ball := Vector3(-0.3, _shooter.position.y, _spec.distance + 0.4)
	tween.tween_property(_shooter, "position", at_ball, duration)


func _place_ball(t: float, start: Vector3, control: Vector3, end: Vector3) -> void:
	var u := 1.0 - t
	_ball.position = u * u * start + 2.0 * u * t * control + t * t * end


## The capsule the player controls: the keeper in save moments, else the shooter.
func _player() -> MeshInstance3D:
	return _keeper if _spec.is_save() else _shooter


func _add_boots(player: MeshInstance3D) -> void:
	var boot := BoxMesh.new()
	boot.size = BOOT_SIZE
	var feet_y := -KEEPER_HEIGHT / 2 + BOOT_SIZE.y / 2
	var material := _material(_look.boots)
	for side: float in [-1.0, 1.0]:
		var instance := MeshInstance3D.new()
		instance.mesh = boot
		instance.material_override = material
		instance.position = Vector3(side * 0.12, feet_y, 0.06)
		player.add_child(instance)


func _keeper_start_x() -> float:
	return _spec.keeper_x if _spec.moment_type == MomentSpec.FREE_KICK else 0.0


func _add_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = false
	add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.55, 0.75, 0.95)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(environment)


func _add_pitch() -> void:
	var pitch := PlaneMesh.new()
	pitch.size = Vector2(70, 70)
	_add_mesh(pitch, PITCH_COLOR, Vector3(0, 0, 25))
	_add_line(Vector3(0, 0.01, 0), Vector2(40, 0.1))
	_add_line(Vector3(0, 0.01, 16.5), Vector2(40.3, 0.1))
	_add_line(Vector3(0, 0.01, 5.5), Vector2(18.3, 0.1))
	for side: float in [-1.0, 1.0]:
		_add_line(Vector3(side * 20.15, 0.01, 8.25), Vector2(0.1, 16.5))
		_add_line(Vector3(side * 9.15, 0.01, 2.75), Vector2(0.1, 5.5))
	_add_line(Vector3(0, 0.01, _tuning.value("penalty", "distance")), Vector2(0.25, 0.25))


func _add_line(center: Vector3, size: Vector2) -> void:
	var line := PlaneMesh.new()
	line.size = size
	_add_mesh(line, LINE_COLOR, center)


func _add_goal() -> void:
	var half_width := _tuning.value("goal", "half_width")
	var height := _tuning.value("goal", "height")
	var post := BoxMesh.new()
	post.size = Vector3(0.12, height, 0.12)
	for side: float in [-1.0, 1.0]:
		_add_mesh(post, LINE_COLOR, Vector3(side * (half_width + 0.06), height / 2, 0))
	var bar := BoxMesh.new()
	bar.size = Vector3(half_width * 2 + 0.24, 0.12, 0.12)
	_add_mesh(bar, LINE_COLOR, Vector3(0, height + 0.06, 0))
	if _spec.is_save():
		return  # The save camera sits behind the goal; a net would fog the view.
	var net := BoxMesh.new()
	net.size = Vector3(half_width * 2, height, 1.5)
	var net_material := _material(Color(1, 1, 1, 0.25))
	net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh_with(net, net_material, Vector3(0, height / 2, -0.8))


func _add_wall() -> void:
	var width := _tuning.value("free_kick", "wall_width")
	var wall_z := _spec.distance - _tuning.value("free_kick", "wall_distance")
	var wall_height := _tuning.value("free_kick", "wall_height")
	for i: int in WALL_PLAYERS:
		var offset := lerpf(-width / 2 + PLAYER_RADIUS, width / 2 - PLAYER_RADIUS, i / 3.0)
		var at := Vector3(_spec.wall_center_x + offset, wall_height / 2, wall_z)
		_add_capsule(_look.opponent_kit, at, wall_height)


func _add_capsule(color: Color, at: Vector3, height: float = KEEPER_HEIGHT) -> MeshInstance3D:
	return _add_mesh(_capsule_mesh(height), color, at)


func _capsule_mesh(height: float) -> CapsuleMesh:
	var capsule := CapsuleMesh.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = height
	# Low-poly: the default 64 segments cost ~4k triangles per player.
	capsule.radial_segments = CAPSULE_SEGMENTS
	capsule.rings = CAPSULE_RINGS
	return capsule


func _add_ball() -> MeshInstance3D:
	var radius := _tuning.value("goal", "ball_radius")
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	sphere.radial_segments = 16
	sphere.rings = 8
	return _add_mesh(sphere, BALL_COLOR, Vector3(0, radius, _spec.distance))


func _add_aim_marker() -> MeshInstance3D:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.18
	disc.bottom_radius = 0.18
	disc.height = 0.02
	var marker := _add_mesh(disc, _look.aim, Vector3.ZERO)
	marker.rotation_degrees.x = 90
	marker.visible = false
	return marker


func _add_camera() -> void:
	_camera = Camera3D.new()
	add_child(_camera)
	if _spec.is_save():
		# Behind the keeper, under the crossbar, facing the shooter.
		_design_fov = 70.0
		_camera.position = Vector3(0, 2.2, -3.2)
		_camera.look_at(Vector3(0, 0.9, _spec.distance))
	elif _spec.moment_type == MomentSpec.ONE_ON_ONE:
		_design_fov = RUN_CAMERA_FOV
		_camera.position = Vector3(0, RUN_CAMERA_HEIGHT, _spec.distance + RUN_CAMERA_BACK)
		_camera.look_at(Vector3(0, 0.3, 0))
	else:
		var penalty_view := _tuning.value("penalty", "distance") + SHOT_CAMERA_BACK
		var fov := SHOT_CAMERA_FOV_AT_PENALTY * penalty_view / (_spec.distance + SHOT_CAMERA_BACK)
		_design_fov = maxf(fov, MIN_CAMERA_FOV)
		_camera.position = Vector3(0, SHOT_CAMERA_HEIGHT, _spec.distance + SHOT_CAMERA_BACK)
		_camera.look_at(Vector3(0, 0.3, 0))
	_camera.current = true
	get_window().size_changed.connect(_fit_camera)
	_fit_camera()


## Landscape keeps the designed height. Portrait (a phone held upright, or a
## browser) keeps the designed width instead, so the goal is never cropped.
func _fit_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	if size.x >= size.y:
		_camera.keep_aspect = Camera3D.KEEP_HEIGHT
		_camera.fov = _design_fov
		return
	var half := tan(deg_to_rad(_design_fov) / 2.0) * DESIGN_ASPECT
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = minf(rad_to_deg(2.0 * atan(half)), MAX_CAMERA_FOV)


func _add_mesh(mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	return _add_mesh_with(mesh, _material(color), at)


func _add_mesh_with(mesh: Mesh, material: StandardMaterial3D, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
