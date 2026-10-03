class_name Warden
extends Node2D
## Mags, the Mire Warden: Hollis's partner, kept by the muck since 1987.
## Throws flasks that leave burning pools, sinks and bursts up under you,
## and lunges. Below half health she gets faster and throws more.

signal defeated

const HP := 26
const BOX := Vector2(22, 50)

var world
var hp := HP
var sprite: AnimatedSprite2D
var lamp: PointLight2D
var state := "dormant"
var state_t := 0.0
var flash := 0.0
var dir := -1
var vx := 0.0
var floor_y := 0.0
var target_x := 0.0
var left_x := 0.0
var right_x := 0.0
var pools: Array = []
var thrown := 0

func setup(w, arena: Rect2) -> void:
	world = w
	floor_y = position.y
	left_x = arena.position.x + 28
	right_x = arena.end.x - 40
	add_to_group("hittable")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Fx.frames("swampthing", 6, 7.0)
	sprite.offset = Vector2(0, -29)
	sprite.play("default")
	add_child(sprite)
	lamp = PointLight2D.new()
	lamp.texture = Fx.light_texture(128, Color(0.6, 1.0, 0.4))
	lamp.energy = 0.0
	lamp.position = Vector2(0, -44)
	add_child(lamp)
	visible = false

func hit_rect() -> Rect2:
	if state in ["dormant", "under", "dead", "rise"]:
		return Rect2(-9999, -9999, 0, 0)
	return Rect2(global_position - Vector2(BOX.x / 2.0, BOX.y), BOX)

func wake() -> void:
	state = "rise"
	state_t = 0.0
	visible = true
	sprite.position.y = 58
	Sfx.play("roar")
	world.shake(4.0, 1.0)
	var t := create_tween()
	t.tween_property(sprite, "position:y", 0.0, 1.2).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(lamp, "energy", 1.0, 1.2)

func angry() -> bool:
	return hp <= HP / 2

func take_hit(dmg: int, _from: Vector2) -> void:
	if hit_rect().size == Vector2.ZERO:
		return
	hp -= dmg
	flash = 0.1
	Sfx.play("hit", 0.7)
	world.hitstop(0.05)
	world.hud.boss_bar(float(hp) / HP)
	Fx.dust(world, global_position + Vector2(0, -30), 5, Color(0.5, 0.9, 0.4))
	if hp <= 0:
		_die()

func _die() -> void:
	state = "dead"
	for p in pools:
		if is_instance_valid(p):
			p.queue_free()
	world.hud.boss_bar(-1.0)
	Sfx.play("roar", 0.6)
	world.shake(5.0, 1.4)
	var t := create_tween()
	for i in 6:
		t.tween_callback(func(): Fx.poof(world, global_position + Vector2(randf_range(-14, 14), randf_range(-50, -5)), 0.7))
		t.tween_interval(0.18)
	t.tween_property(sprite, "position:y", 60.0, 1.4).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(lamp, "energy", 0.0, 1.4)
	t.tween_callback(func(): defeated.emit())

func _process(delta: float) -> void:
	if state in ["dormant", "dead"]:
		return
	state_t += delta
	flash = max(0.0, flash - delta)
	sprite.self_modulate = Color(3, 3, 3) if flash > 0.0 else Color.WHITE
	var p: Player = world.player
	var px := p.global_position.x
	var speed := 1.35 if angry() else 1.0
	sprite.flip_h = px > global_position.x
	match state:
		"rise":
			if state_t > 1.4:
				_next("walk")
		"walk":
			dir = 1 if px > global_position.x else -1
			position.x += dir * 26.0 * speed * delta
			if state_t > (1.2 if angry() else 1.8):
				var r := randf()
				if r < 0.4:
					_next("throw")
				elif r < 0.7:
					_next("sink")
				else:
					_next("windup")
		"throw":
			var n := 3 if angry() else 2
			if thrown < n and state_t > 0.35 + thrown * 0.3:
				thrown += 1
				_throw(px + randf_range(-40, 40))
			if state_t > 0.9 + n * 0.3:
				_next("walk")
		"sink":
			sprite.position.y = min(58.0, sprite.position.y + 90.0 * delta)
			if state_t > 0.7:
				target_x = clamp(px, left_x, right_x)
				_next("under")
		"under":
			# Bubbles where she'll come up.
			position.x = move_toward(position.x, target_x, 160.0 * delta)
			if randf() < 0.4:
				Fx.dust(world, Vector2(target_x + randf_range(-10, 10), floor_y), 1, Color(0.6, 0.95, 0.4))
			if state_t > (0.7 if angry() else 1.0):
				_next("burst")
				Sfx.play("roar", 1.3)
				world.shake(3.0, 0.3)
		"burst":
			sprite.position.y = max(0.0, sprite.position.y - 400.0 * delta)
			if state_t > 0.5:
				_next("walk")
		"windup":
			dir = 1 if px > global_position.x else -1
			sprite.position.x = sin(state_t * 60.0) * 1.5
			if state_t > 0.5:
				sprite.position.x = 0
				vx = dir * 190.0 * speed
				_next("lunge")
		"lunge":
			position.x += vx * delta
			vx = move_toward(vx, 0.0, 260.0 * delta)
			if absf(vx) < 10.0 or position.x < left_x or position.x > right_x:
				_next("walk")
	position.x = clamp(position.x, left_x, right_x)
	var hr := hit_rect()
	if hr.size != Vector2.ZERO and hr.grow(-2).intersects(p.rect()):
		p.hurt(1, global_position.x)
	if state == "burst" and state_t < 0.3 and Rect2(global_position.x - 16, floor_y - 60, 32, 60).intersects(p.rect()):
		p.hurt(1, global_position.x)

func _next(s: String) -> void:
	state = s
	thrown = 0
	state_t = 0.0

func _throw(x: float) -> void:
	var flask := AnimatedSprite2D.new()
	flask.sprite_frames = Fx.frames("acid_potion", 4, 12.0)
	flask.play("default")
	flask.position = global_position + Vector2(0, -50)
	world.add_effect(flask)
	var to := Vector2(clamp(x, left_x - 10, right_x + 20), floor_y - 4)
	var mid := (flask.position + to) / 2.0 + Vector2(0, -70)
	var t := flask.create_tween()
	var start := flask.position
	t.tween_method(func(k: float):
		flask.position = start.lerp(mid, k).lerp(mid.lerp(to, k), k), 0.0, 1.0, 0.7)
	t.tween_callback(func():
		flask.queue_free()
		Sfx.play("thud", 1.5)
		_pool(to))

func _pool(at: Vector2) -> void:
	if state == "dead":
		return
	var pool := AnimatedSprite2D.new()
	pool.sprite_frames = Fx.frames("acid_pool", 6, 8.0)
	pool.play("default")
	pool.position = at + Vector2(0, -12)
	world.add_effect(pool)
	pools.append(pool)
	var r := Rect2(at.x - 12, at.y - 8, 24, 10)
	var life := [0.0]
	var tick := func(dt: float) -> bool:
		life[0] += dt
		if world.player and r.intersects(world.player.rect()):
			world.player.hurt(1, at.x)
		return life[0] < 2.6
	world.add_ticker(tick, pool)
