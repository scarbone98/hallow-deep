class_name Enemy
extends CharacterBody2D
## The things that live in the caves. One script, behaviour picked by kind.
## The origin is at the creature's feet (its centre for flyers).

const KINDS := {
	# sheet, frames, fps, faces (1 = drawn facing right), hp, box, contact damage, candy
	"husk": {"sheet": "zombie", "n": 6, "fps": 7, "faces": 1, "hp": 3, "box": Vector2(10, 20), "dmg": 1, "candy": 2, "tint": "#c9d6c0"},
	"pumpling": {"sheet": "pumpkin", "n": 6, "fps": 10, "faces": -1, "hp": 2, "box": Vector2(12, 12), "dmg": 1, "candy": 1},
	"bat": {"sheet": "bat", "n": 4, "fps": 12, "faces": 1, "hp": 1, "box": Vector2(14, 10), "dmg": 1, "candy": 1, "fly": true},
	"wraith": {"sheet": "ghost", "n": 6, "fps": 8, "faces": -1, "hp": 3, "box": Vector2(12, 22), "dmg": 1, "candy": 3, "fly": true, "tint": "#c0b8ff"},
	"werewolf": {"sheet": "werewolf", "n": 7, "fps": 12, "faces": -1, "hp": 6, "box": Vector2(22, 18), "dmg": 2, "candy": 6},
	"wisp": {"sheet": "willOWisp", "n": 6, "fps": 10, "faces": 1, "hp": 1, "box": Vector2(10, 10), "dmg": 0, "candy": 4, "fly": true},
}
const GRAVITY := 800.0

var world
var kind := "husk"
var def: Dictionary
var hp := 1
var dir := -1
var sprite: AnimatedSprite2D
var home := Vector2.ZERO
var t := 0.0
var state := "idle"
var state_t := 0.0
var flash := 0.0
var stun := 0.0
var key := ""  # "<room>:<x>,<y>", so one-off kills could be remembered

func setup(k: String, w) -> void:
	kind = k
	world = w
	def = KINDS[k]
	hp = def.hp
	add_to_group("hittable")
	add_to_group("enemies")
	collision_layer = 0
	collision_mask = 0 if kind in ["wraith", "wisp"] else (1 | 8)
	if def.get("fly", false) and kind == "bat":
		collision_mask = 1
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = def.box
	shape.shape = r
	shape.position = Vector2(0, -def.box.y / 2.0) if not def.get("fly", false) else Vector2.ZERO
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Fx.frames(def.sheet, def.n, def.fps)
	var fh: float = sprite.sprite_frames.get_frame_texture("default", 0).get_height()
	sprite.offset = Vector2(0, -fh / 2.0) if not def.get("fly", false) else Vector2.ZERO
	if def.has("tint"):
		sprite.modulate = Color(def.tint)
	sprite.play("default")
	sprite.frame = randi() % def.n
	add_child(sprite)
	if kind == "wraith":
		sprite.modulate.a = 0.75
	if kind == "wisp":
		var l := PointLight2D.new()
		l.texture = Fx.light_texture(96, Color(0.5, 1.0, 0.95))
		l.energy = 0.9
		add_child(l)
	if kind == "bat":
		state = "roost"
		sprite.pause()
		sprite.frame = 3
	home = position
	dir = -1 if randf() < 0.5 else 1

func hit_rect() -> Rect2:
	var b: Vector2 = def.box
	if def.get("fly", false):
		return Rect2(global_position - b / 2.0, b)
	return Rect2(global_position - Vector2(b.x / 2.0, b.y), b)

func take_hit(dmg: int, from: Vector2) -> void:
	if hp <= 0:
		return
	hp -= dmg
	flash = 0.12
	stun = 0.2
	Sfx.play("hit")
	world.hitstop(0.04)
	Fx.dust(world, hit_rect().get_center(), 4, Color(0.9, 0.85, 1.0))
	velocity = Vector2(from.x * 120.0, -60.0 if from.y == 0 else from.y * 80.0)
	if kind in ["werewolf"]:
		velocity.x *= 0.4
	if hp <= 0:
		_die()

func _die() -> void:
	Sfx.play("kill")
	Fx.poof(world, hit_rect().get_center(), 0.5)
	world.drop_candy(hit_rect().get_center(), def.candy)
	queue_free()

func _physics_process(delta: float) -> void:
	t += delta
	state_t += delta
	flash = max(0.0, flash - delta)
	sprite.self_modulate = Color(3, 3, 3) if flash > 0.0 else Color.WHITE
	var p: Player = world.player
	var to_p := p.global_position - global_position if p else Vector2(9999, 0)
	if stun > 0.0:
		stun -= delta
		if not def.get("fly", false):
			velocity.y += GRAVITY * delta
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
	else:
		call("_act_" + kind, delta, to_p)
	if velocity.x != 0.0:
		sprite.flip_h = (velocity.x > 0.0) != (def.faces > 0)
	# Touching you hurts (wisps are harmless).
	if p and def.dmg > 0 and hp > 0 and hit_rect().grow(-1).intersects(p.rect()):
		p.hurt(def.dmg, global_position.x)

func _ledge_ahead() -> bool:
	var foot := global_position + Vector2(dir * (def.box.x / 2.0 + 2.0), 4)
	return not world.solid_at(foot) or world.solid_at(foot + Vector2(0, -10)) or world.hazard_at(foot + Vector2(0, -4)) != ""

func _act_husk(delta: float, to_p: Vector2) -> void:
	# Shuffles back and forth; lurches toward you when you're close and level.
	var speed := 18.0
	if absf(to_p.x) < 90.0 and absf(to_p.y) < 24.0:
		dir = 1 if to_p.x > 0 else -1
		speed = 34.0
	if is_on_floor() and (is_on_wall() or _ledge_ahead()):
		dir = -dir
	velocity.x = dir * speed
	velocity.y += GRAVITY * delta
	move_and_slide()

func _act_pumpling(delta: float, to_p: Vector2) -> void:
	velocity.y += GRAVITY * delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		if state_t > 1.1 and absf(to_p.x) < 150.0:
			dir = 1 if to_p.x > 0 else -1
			velocity = Vector2(dir * 70.0, -220.0)
			state_t = randf() * 0.3
	move_and_slide()

func _act_bat(delta: float, to_p: Vector2) -> void:
	if state == "roost":
		if to_p.length() < 90.0:
			state = "swoop"
			sprite.play("default")
		return
	var target := to_p + Vector2(0, -14)
	var want := target.normalized() * 70.0 + Vector2(0, sin(t * 6.0) * 50.0)
	velocity = velocity.move_toward(want, 220.0 * delta)
	move_and_slide()

func _act_wraith(delta: float, to_p: Vector2) -> void:
	# Drifts through rock toward you, fading in and out.
	var target := to_p + Vector2(0, -12)
	if target.length() < 180.0:
		velocity = velocity.move_toward(target.normalized() * 32.0, 60.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2(sin(t * 0.7) * 10.0, cos(t) * 6.0), 30.0 * delta)
	sprite.modulate.a = 0.45 + 0.3 * sin(t * 2.0)
	position += velocity * delta

func _act_werewolf(delta: float, to_p: Vector2) -> void:
	velocity.y += GRAVITY * delta
	match state:
		"idle":
			velocity.x = dir * 30.0
			if is_on_floor() and (is_on_wall() or _ledge_ahead()):
				dir = -dir
			if absf(to_p.y) < 30.0 and absf(to_p.x) < 140.0 and state_t > 1.0:
				state = "crouch"
				state_t = 0.0
				dir = 1 if to_p.x > 0 else -1
		"crouch":
			velocity.x = 0.0
			sprite.speed_scale = 0.3
			if state_t > 0.45:
				state = "charge"
				state_t = 0.0
				sprite.speed_scale = 1.6
				Sfx.play("roar", 1.8)
		"charge":
			velocity.x = dir * 170.0
			if is_on_wall() or state_t > 0.9 or _ledge_ahead():
				state = "idle"
				state_t = 0.0
				sprite.speed_scale = 1.0
				if is_on_wall():
					world.shake(2.0, 0.15)
	move_and_slide()

func _act_wisp(delta: float, to_p: Vector2) -> void:
	# A cave critter: drifts near home and shies away from you.
	var flee := Vector2.ZERO
	if to_p.length() < 50.0:
		flee = -to_p.normalized() * 40.0
	var wander := (home + Vector2(sin(t * 0.6) * 30.0, sin(t * 1.1) * 12.0)) - position
	velocity = velocity.move_toward(wander * 0.8 + flee, 80.0 * delta)
	position += velocity * delta
