class_name Player
extends CharacterBody2D
## You: your Scareathon avatar with a cursed sword and a lantern.
## The origin is at your feet.

signal died

const GRAVITY := 900.0
const MAX_FALL := 320.0
const RUN := 100.0
const ACCEL := 900.0
const JUMP_V := -320.0
const FLAP_V := -270.0
const COYOTE := 0.1
const BUFFER := 0.12
const SWING_TIME := 0.28
const SWING_COOLDOWN := 0.32
const INVULN := 1.1
const BOX := Vector2(8, 20)

var world  # World
var facing := 1
var sprite: AnimatedSprite2D
var sword: AnimatedSprite2D
var wings: AnimatedSprite2D
var light: PointLight2D
var coyote := 0.0
var buffer := 0.0
var flaps := 0
var swing_t := 0.0
var swing_cd := 0.0
var swing_dir := Vector2.RIGHT
var swing_hit := {}  # enemies already hit by this swing
var invuln := 0.0
var hurt_t := 0.0
var safe_pos := Vector2.ZERO  # last solid footing, for hazard respawns
var frozen := false  # cutscenes and dialogue
var dead := false
# The four kids use full 3D-rendered sheets (KidSprites) instead of the layered avatar.
var kid := ""
var combo := 0      # which hit of the sword combo the current swing is (1..3)
var combo_t := 0.0  # time left to chain the next hit
var land_t := 0.0   # landing pose after a real drop
var flap_t := 0.0   # double-jump pose after a bat-wing flap
var air_vy := 0.0   # fall speed just before touching down
var kid_target := ""  # state animation to play once a transition clip finishes
var swing_anim := ""  # the attack animation chosen when the swing started (kept until it ends)
var trace := false     # ?trace=1 on the web: log every animation frame to window.__hdTrace (tests)
var trace_t := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 8
	floor_snap_length = 4.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BOX
	shape.shape = rect
	shape.position = Vector2(0, -BOX.y / 2.0)
	add_child(shape)

	light = PointLight2D.new()
	light.texture = Fx.light_texture(220, Color(1.0, 0.85, 0.6))
	light.energy = 1.0
	light.position = Vector2(0, -14)
	add_child(light)

	wings = AnimatedSprite2D.new()
	wings.sprite_frames = Fx.frames("bat", 4, 16.0)
	wings.position = Vector2(0, -16)
	wings.visible = false
	wings.modulate = Color(0.75, 0.7, 0.9)
	add_child(wings)

	sprite = AnimatedSprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-16, -47)
	add_child(sprite)
	set_look(Bridge.look if not Bridge.look.is_empty() else {})

	sword = AnimatedSprite2D.new()
	sword.sprite_frames = Fx.frames("cursed_sword", 6, 26.0, false)
	sword.visible = false
	add_child(sword)
	safe_pos = global_position

func set_look(look: Dictionary) -> void:
	# A kid picked on the title screen stays picked, even when the page's avatar look arrives later.
	if Game.character in KidSprites.KIDS and not Bridge.flags().has("outfit"):
		look = KidSprites.look_for(Game.character)
	if look.is_empty():
		var f := Bridge.flags()
		if f.has("outfit"):
			for file in AvatarBuilder.outfit_files():
				if str(f.outfit) in file:
					look = AvatarBuilder.outfit_look(file)
		if look.is_empty():
			look = AvatarBuilder.guest_look()
	kid = KidSprites.kid_for(look)
	if kid != "":
		var k := KidSprites.build(kid)
		sprite.sprite_frames = k.frames
		sprite.offset = -k.pivot  # the sheets' pivot is the feet, like the player's origin
	else:
		sprite.sprite_frames = AvatarBuilder.build(look)
		sprite.offset = Vector2(-16, -47)
	sprite.play("idle")
	trace = OS.has_feature("web") and Bridge.flags().has("trace")
	if trace:
		JavaScriptBridge.eval("window.__hdTrace = []")

func rect() -> Rect2:
	return Rect2(global_position - Vector2(BOX.x / 2.0, BOX.y), BOX)

func _physics_process(delta: float) -> void:
	if dead:
		return
	invuln = max(0.0, invuln - delta)
	hurt_t = max(0.0, hurt_t - delta)
	swing_cd = max(0.0, swing_cd - delta)
	combo_t = max(0.0, combo_t - delta)
	land_t = max(0.0, land_t - delta)
	flap_t = max(0.0, flap_t - delta)
	var was_on_floor := is_on_floor()
	sprite.visible = invuln <= 0.0 or int(invuln * 20.0) % 2 == 0

	var move := 0.0
	if not frozen and hurt_t <= 0.0:
		move = Input.get_axis("left", "right")
	if is_on_floor():
		coyote = COYOTE
		flaps = 0
	else:
		coyote -= delta

	if not frozen and Input.is_action_just_pressed("jump"):
		buffer = BUFFER
	else:
		buffer -= delta

	velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL)
	if buffer > 0.0:
		if coyote > 0.0:
			_jump(JUMP_V)
		elif Game.has("double_jump") and flaps == 0:
			flaps = 1
			_jump(FLAP_V)
			_flap()
	if velocity.y < 0.0 and not Input.is_action_pressed("jump") and not frozen:
		velocity.y = max(velocity.y, -90.0)  # short hop when released early
	# Drop through ledges: down + jump while standing on one.
	if not frozen and is_on_floor() and Input.is_action_pressed("down") and Input.is_action_just_pressed("jump"):
		position.y += 2
		buffer = 0.0

	if hurt_t <= 0.0:
		velocity.x = move_toward(velocity.x, move * RUN, ACCEL * delta)
		if move != 0.0 and swing_t <= 0.0:
			facing = 1 if move > 0.0 else -1
	if not was_on_floor:
		air_vy = velocity.y
	move_and_slide()
	if is_on_floor() and not was_on_floor and air_vy > 140.0:
		land_t = 0.18
		if kid != "" and sprite.sprite_frames.has_animation("jump_land"):
			# play the whole landing clip: its transition clips start from its last frame
			var sf := sprite.sprite_frames
			land_t = sf.get_frame_count("jump_land") / sf.get_animation_speed("jump_land")

	if not frozen and Input.is_action_just_pressed("attack") and swing_cd <= 0.0:
		_swing()
	_update_swing(delta)
	_animate()
	if trace:
		trace_t += delta
		JavaScriptBridge.eval("window.__hdTrace.push(%s)" % JSON.stringify({
			"t": snappedf(trace_t, 0.001), "anim": str(sprite.animation), "frame": sprite.frame,
			"floor": is_on_floor(), "vx": int(velocity.x), "vy": int(velocity.y), "swing": swing_t > 0.0,
			"sx": int(get_global_transform_with_canvas().origin.x),
			"sy": int(get_global_transform_with_canvas().origin.y)}))
	if is_on_floor() and not world.hazard_under(self) and world.hazard_in(rect().grow(6)) == "":
		safe_pos = global_position

func _jump(v: float) -> void:
	velocity.y = v
	coyote = 0.0
	buffer = 0.0

func _flap() -> void:
	flap_t = 0.35
	wings.visible = true
	wings.frame = 0
	wings.play("default")
	var t := create_tween()
	t.tween_interval(0.3)
	t.tween_callback(func(): wings.visible = false)
	Fx.dust(world, global_position, 4)

func _swing() -> void:
	swing_t = SWING_TIME
	swing_cd = SWING_COOLDOWN
	swing_hit = {}
	if Input.is_action_pressed("up"):
		swing_dir = Vector2.UP
	elif Input.is_action_pressed("down") and not is_on_floor():
		swing_dir = Vector2.DOWN
	else:
		swing_dir = Vector2(facing, 0)
	sword.visible = true
	sword.frame = 0
	sword.play("default")
	sword.flip_h = false
	sword.flip_v = false
	match swing_dir:
		Vector2.UP:
			sword.rotation = -PI / 2.0
			sword.position = Vector2(0, -30)
		Vector2.DOWN:
			sword.rotation = PI / 2.0
			sword.position = Vector2(0, 4)
		_:
			sword.rotation = 0.0
			sword.flip_h = facing < 0
			sword.position = Vector2(14 * facing, -14)
	if kid != "":
		# the kid's own animation swings the sword; the overlay would be a second one
		sword.visible = false
		combo = combo % 3 + 1 if combo_t > 0.0 else 1
		combo_t = SWING_TIME + 0.35
		swing_anim = _have([_attack_anim(), "sword_1", "swing"])
		kid_target = ""
		sprite.play(swing_anim)
		sprite.frame = 0
	Sfx.play("swing")

func _attack_anim() -> String:
	if swing_dir == Vector2.UP:
		return "slash_up"
	if swing_dir == Vector2.DOWN:
		return "slash_down"
	if not is_on_floor():
		return "air_attack"
	return "sword_%d" % combo

## The first animation in `names` the kid's sheet has.
func _have(names: Array) -> String:
	for n in names:
		if sprite.sprite_frames.has_animation(n):
			return n
	return "idle"

func swing_rect() -> Rect2:
	var p := global_position
	match swing_dir:
		Vector2.UP:
			return Rect2(p + Vector2(-11, -48), Vector2(22, 26))
		Vector2.DOWN:
			return Rect2(p + Vector2(-11, -6), Vector2(22, 24))
	return Rect2(p + Vector2(2 if facing > 0 else -28, -26), Vector2(26, 22))

func _update_swing(delta: float) -> void:
	if swing_t <= 0.0:
		sword.visible = false
		return
	swing_t -= delta
	if swing_t < SWING_TIME - 0.16:
		return  # only the first part of the swing hurts
	var r := swing_rect()
	var bounced := false
	for e in get_tree().get_nodes_in_group("hittable"):
		if swing_hit.has(e) or not e.has_method("hit_rect"):
			continue
		if r.intersects(e.hit_rect()):
			swing_hit[e] = true
			e.take_hit(1, swing_dir if swing_dir.y != 0 else Vector2(facing, 0))
			bounced = true
			if swing_dir.x != 0:
				velocity.x = -facing * 60.0  # recoil
	if swing_dir == Vector2.DOWN and (bounced or world.hazard_in(r) == "spike"):
		velocity.y = -260.0
		flaps = 0
		swing_t = min(swing_t, SWING_TIME - 0.17)

func _animate() -> void:
	sprite.flip_h = facing < 0
	wings.flip_h = facing < 0
	if kid != "":
		_animate_kid()
		return
	var anim := "idle"
	if hurt_t > 0.0:
		anim = "hurt"
	elif not is_on_floor():
		anim = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 10.0:
		anim = "run"
	if sprite.animation != anim:
		sprite.play(anim)

func _animate_kid() -> void:
	var anim: String
	if dead:
		anim = _have(["death", "dying"])
	elif hurt_t > 0.0:
		anim = _have(["hurt"])
	elif swing_t > 0.0:
		anim = swing_anim  # landing mid air-swing must not swap it for a ground swing
	elif not is_on_floor():
		if flap_t > 0.0:
			anim = _have(["double_jump", "jump"])
		elif velocity.y < 0.0:
			anim = _have(["jump"])
		else:
			anim = _have(["fall", "jump_fall"])
	elif land_t > 0.0:
		anim = _have(["jump_land", "land"])
	elif absf(velocity.x) > 10.0:
		anim = _have(["run", "walk"])
	else:
		anim = _have(["idle"])
	_play_kid(anim)

## Switch the kid's animation, through a baked transition clip when the sheet has one:
## "<from>-to-<to>" (from a one-shot) or "<from>-to-<to>-<frame>" (leaving a loop on that frame).
## The game logic never waits on it: a new state request just replaces it.
func _play_kid(anim: String) -> void:
	var cur := sprite.animation
	if kid_target != "":
		if anim == kid_target and sprite.is_playing():
			return  # still easing into it
		if anim == kid_target:
			kid_target = ""
			sprite.play(anim)
			return
		kid_target = ""
	if cur == anim:
		return
	var sf := sprite.sprite_frames
	var via := "%s-to-%s" % [cur, anim]
	if sf.get_animation_loop(cur) and sf.has_animation("%s-%d" % [via, sprite.frame]):
		via = "%s-%d" % [via, sprite.frame]
	if sf.has_animation(via):
		kid_target = anim
		sprite.play(via)
	else:
		sprite.play(anim)

## Hurt by something at world x `from_x`. Returns false while invulnerable.
func hurt(n: int, from_x: float) -> bool:
	if invuln > 0.0 or dead or frozen or Bridge.flags().has("god"):  # ?god: attract / recording runs
		return false
	Game.hurt(n)
	invuln = INVULN
	hurt_t = 0.25
	velocity = Vector2(140.0 * (1.0 if global_position.x >= from_x else -1.0), -160.0)
	world.shake(3.0, 0.2)
	world.hitstop(0.06)
	Sfx.play("hurt")
	if Game.hp <= 0:
		dead = true
		_animate()  # kids fall down (death) before the world takes over
		died.emit()
	return true

## Spikes, muck and the abyss: take a hit and go back to solid ground.
func hazard(n: int) -> void:
	if dead:
		return
	var was_inv := invuln
	invuln = 0.0
	Game.hurt(n)
	Sfx.play("hurt")
	world.shake(3.0, 0.2)
	if Game.hp <= 0:
		dead = true
		died.emit()
		return
	invuln = max(was_inv, INVULN)
	velocity = Vector2.ZERO
	global_position = safe_pos
	world.fade_flash()
