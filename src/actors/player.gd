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
	if look.is_empty():
		var f := Bridge.flags()
		if f.has("outfit"):
			for file in AvatarBuilder.outfit_files():
				if str(f.outfit) in file:
					look = AvatarBuilder.outfit_look(file)
		if look.is_empty():
			look = AvatarBuilder.guest_look()
	sprite.sprite_frames = AvatarBuilder.build(look)
	sprite.play("idle")

func rect() -> Rect2:
	return Rect2(global_position - Vector2(BOX.x / 2.0, BOX.y), BOX)

func _physics_process(delta: float) -> void:
	if dead:
		return
	invuln = max(0.0, invuln - delta)
	hurt_t = max(0.0, hurt_t - delta)
	swing_cd = max(0.0, swing_cd - delta)
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
	move_and_slide()

	if not frozen and Input.is_action_just_pressed("attack") and swing_cd <= 0.0:
		_swing()
	_update_swing(delta)
	_animate()
	if is_on_floor() and not world.hazard_under(self) and world.hazard_in(rect().grow(6)) == "":
		safe_pos = global_position

func _jump(v: float) -> void:
	velocity.y = v
	coyote = 0.0
	buffer = 0.0

func _flap() -> void:
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
	Sfx.play("swing")

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
	var anim := "idle"
	if hurt_t > 0.0:
		anim = "hurt"
	elif not is_on_floor():
		anim = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 10.0:
		anim = "run"
	if sprite.animation != anim:
		sprite.play(anim)

## Hurt by something at world x `from_x`. Returns false while invulnerable.
func hurt(n: int, from_x: float) -> bool:
	if invuln > 0.0 or dead or frozen:
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
