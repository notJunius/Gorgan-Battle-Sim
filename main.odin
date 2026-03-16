package main

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

SCREEN_W :: 1320
SCREEN_H :: 760
PANEL_W :: 320

ARENA_X :: f32(PANEL_W + 24)
ARENA_Y :: f32(24)
ARENA_W :: f32(960)
ARENA_H :: f32(620)
WALL :: f32(20)

MAX_UNITS :: 64
MAX_PROJECTILES :: 128
MAX_TRAPS :: 128
MAX_EFFECTS :: 256

Fighter_Kind :: enum {
	Sword,
	Trapper,
	Toxic,
	Inferno,
	Spider,
	Zombie,
	Larry,
}

Projectile_Kind :: enum {
	Trap_Shot,
	Web_Shot,
}

Trap_Kind :: enum {
	Cage,
	Web,
}

Effect_Kind :: enum {
	Ring,
	Slash,
	Text,
}

Button_Result :: enum {
	None,
	Hovered,
	Pressed,
}

Status_Tag :: struct {
	label: string,
	active: bool,
}

Poison_Def :: struct {
	dps: f32,
	duration: f32,
}

Trap_Def :: struct {
	life: f32,
	radius: f32,
	wall_damage: f32,
	wall_knock: f32,
	projectile_speed: f32,
}

Beam_Def :: struct {
	range: f32,
	base_dps: f32,
	growth: f32,
}

Web_Def :: struct {
	projectile_speed: f32,
	radius: f32,
	trap_radius: f32,
	life: f32,
	poison: Poison_Def,
}

Infect_Def :: struct {
	duration: f32,
}

Helpers_Def :: struct {
	count: int,
	hp: f32,
	cooldown: f32,
}

Fighter_Def :: struct {
	name: string,
	color: rl.Color,
	hp: f32,
	radius: f32,
	speed: f32,
	mass: f32,
	damage: f32,
	cooldown: f32,
	range: f32,
	knockback: f32,
	ai_spider: bool,
	ai_zoner: bool,
	has_trap: bool,
	trap: Trap_Def,
	has_poison: bool,
	poison: Poison_Def,
	has_beam: bool,
	beam: Beam_Def,
	has_web: bool,
	web: Web_Def,
	revive: bool,
	has_infect: bool,
	infect: Infect_Def,
	has_helpers: bool,
	helpers: Helpers_Def,
}

Unit :: struct {
	uid: int,
	kind: Fighter_Kind,
	name: string,
	team: int,
	x: f32,
	y: f32,
	vx: f32,
	vy: f32,
	r: f32,
	color: rl.Color,
	hp: f32,
	max_hp: f32,
	speed: f32,
	mass: f32,
	damage: f32,
	cooldown: f32,
	range: f32,
	knockback: f32,
	def: ^Fighter_Def,
	dead: bool,
	revived: bool,
	owner_uid: int,
	is_helper: bool,
	attack_timer: f32,
	stun: f32,
	burn: f32,
	burn_dps: f32,
	poison: f32,
	poison_dps: f32,
	infected_by: int,
	beam_target_uid: int,
	beam_time: f32,
	helper_cooldown: f32,
	last_webbed_enemy_uid: int,
	last_webbed_enemy_timer: f32,
	helper_contact_cooldown: f32,
	webbed_by: int,
	webbed_time: f32,
	web_anchor_x: f32,
	web_anchor_y: f32,
}

Projectile :: struct {
	kind: Projectile_Kind,
	owner_uid: int,
	team: int,
	x: f32,
	y: f32,
	vx: f32,
	vy: f32,
	r: f32,
	life: f32,
	color: rl.Color,
}

Trap :: struct {
	kind: Trap_Kind,
	owner_uid: int,
	team: int,
	x: f32,
	y: f32,
	r: f32,
	life: f32,
	max_life: f32,
	wall_damage: f32,
	wall_knock: f32,
}

Effect :: struct {
	kind: Effect_Kind,
	x: f32,
	y: f32,
	nx: f32,
	ny: f32,
	r: f32,
	max_r: f32,
	life: f32,
	max_life: f32,
	color: rl.Color,
	text_value: f32,
}

UI_State :: struct {
	active_slider: int,
}

Game_State :: struct {
	units: [MAX_UNITS]Unit,
	unit_count: int,
	projectiles: [MAX_PROJECTILES]Projectile,
	projectile_count: int,
	traps: [MAX_TRAPS]Trap,
	trap_count: int,
	effects: [MAX_EFFECTS]Effect,
	effect_count: int,
	winner_team: int,
	started: bool,
	bounce: f32,
	gravity: f32,
	sim_speed: f32,
	fighter_a: Fighter_Kind,
	fighter_b: Fighter_Kind,
	ui: UI_State,
	next_uid: int,
}

fighter_defs := [?]Fighter_Def{
	{
		name = "Basic Sword",
		color = rl.Color{0x60, 0xa5, 0xfa, 0xff},
		hp = 100,
		radius = 26,
		speed = 180,
		mass = 1.0,
		damage = 12,
		cooldown = 0.55,
		range = 62,
		knockback = 260,
	},
	{
		name = "Trapper",
		color = rl.Color{0xa7, 0x8b, 0xfa, 0xff},
		hp = 112,
		radius = 28,
		speed = 150,
		mass = 1.05,
		damage = 3,
		cooldown = 2.5,
		range = 250,
		knockback = 80,
		ai_zoner = true,
		has_trap = true,
		trap = {life = 3.2, radius = 72, wall_damage = 8, wall_knock = 280, projectile_speed = 360},
	},
	{
		name = "Toxic Blade",
		color = rl.Color{0x34, 0xd3, 0x99, 0xff},
		hp = 95,
		radius = 25,
		speed = 185,
		mass = 0.95,
		damage = 8,
		cooldown = 0.48,
		range = 58,
		knockback = 220,
		has_poison = true,
		poison = {dps = 5, duration = 3.5},
	},
	{
		name = "Inferno",
		color = rl.Color{0xfb, 0x92, 0x3c, 0xff},
		hp = 92,
		radius = 24,
		speed = 165,
		mass = 0.92,
		damage = 0,
		cooldown = 0.12,
		range = 245,
		knockback = 25,
		ai_zoner = true,
		has_beam = true,
		beam = {range = 250, base_dps = 4, growth = 2.2},
	},
	{
		name = "Spider",
		color = rl.Color{0xf4, 0x72, 0xb6, 0xff},
		hp = 98,
		radius = 25,
		speed = 175,
		mass = 0.96,
		damage = 4,
		cooldown = 1.25,
		range = 250,
		knockback = 90,
		ai_spider = true,
		has_web = true,
		web = {projectile_speed = 380, radius = 11, trap_radius = 30, life = 4.0, poison = {dps = 4.5, duration = 4.5}},
	},
	{
		name = "Zombie",
		color = rl.Color{0x84, 0xcc, 0x16, 0xff},
		hp = 120,
		radius = 27,
		speed = 155,
		mass = 1.08,
		damage = 10,
		cooldown = 0.7,
		range = 58,
		knockback = 210,
		revive = true,
		has_infect = true,
		infect = {duration = 12},
	},
	{
		name = "Larry",
		color = rl.Color{0xf8, 0x71, 0x71, 0xff},
		hp = 145,
		radius = 31,
		speed = 150,
		mass = 1.22,
		damage = 16,
		cooldown = 0.78,
		range = 60,
		knockback = 340,
		has_helpers = true,
		helpers = {count = 2, hp = 2, cooldown = 1.0},
	},
}

main :: proc() {
	rl.SetConfigFlags({.MSAA_4X_HINT})
	rl.InitWindow(SCREEN_W, SCREEN_H, "Weapon Ball Fight - Odin + raylib")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	state := Game_State{
		bounce = 0.92,
		gravity = 0,
		sim_speed = 1,
		fighter_a = .Sword,
		fighter_b = .Trapper,
	}

	reset_match(&state)

	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)

		handle_ui(&state)

		if rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ENTER) {
			state.started = true
		}

		dt := min_f32(0.03, rl.GetFrameTime()) * state.sim_speed
		if state.started && state.winner_team == 0 {
			update_game(&state, dt)
		}

		rl.BeginDrawing()
		rl.ClearBackground(color_hex(0x111827ff))
		draw_ui(&state)
		draw_arena(&state)
		rl.EndDrawing()
	}
}

reset_match :: proc(state: ^Game_State) {
	state.unit_count = 0
	state.projectile_count = 0
	state.trap_count = 0
	state.effect_count = 0
	state.winner_team = 0
	state.started = false
	state.next_uid = 1

	spawn_fighter(state, state.fighter_a, 1, arena_left() + 180, arena_top() + ARENA_H * 0.5, 1, false, 0)
	spawn_fighter(state, state.fighter_b, 2, arena_right() - 180, arena_top() + ARENA_H * 0.5, -1, false, 0)
}

spawn_fighter :: proc(state: ^Game_State, kind: Fighter_Kind, team: int, x, y: f32, facing: f32, is_helper: bool, owner_uid: int) -> ^Unit {
	if state.unit_count >= MAX_UNITS {
		return nil
	}
	def := &fighter_defs[int(kind)]
	unit := &state.units[state.unit_count]
	state.unit_count += 1

	unit^ = Unit{
		uid = state.next_uid,
		kind = kind,
		name = def.name,
		team = team,
		x = x,
		y = y,
		vx = facing * 90,
		vy = rand_range(-40, 40),
		r = def.radius,
		color = def.color,
		hp = def.hp,
		max_hp = def.hp,
		speed = def.speed,
		mass = def.mass,
		damage = def.damage,
		cooldown = def.cooldown,
		range = def.range,
		knockback = def.knockback,
		def = def,
		owner_uid = owner_uid,
		is_helper = is_helper,
		attack_timer = rand_range(0, 0.2),
	}

	if is_helper {
		unit.name = "Larry Helper"
		unit.r = 12
		unit.color = color_hex(0xfecacaff)
		unit.hp = 2
		unit.max_hp = 2
		unit.speed = 255
		unit.mass = 0.45
		unit.damage = 4
		unit.cooldown = 0.2
		unit.range = 26
		unit.knockback = 110
	}

	state.next_uid += 1
	return unit
}

update_game :: proc(state: ^Game_State, dt: f32) {
	for i := 0; i < state.unit_count; i += 1 {
		update_unit(state, &state.units[i], dt)
	}

	for i := 0; i < state.unit_count; i += 1 {
		for j := i + 1; j < state.unit_count; j += 1 {
			resolve_pair_collision(state, &state.units[i], &state.units[j])
		}
	}

	update_projectiles(state, dt)
	update_traps(state, dt)
	update_effects(state, dt)
	maybe_set_winner(state)
}

update_unit :: proc(state: ^Game_State, unit: ^Unit, dt: f32) {
	if unit.dead {
		return
	}

	update_statuses(state, unit, dt)
	if unit.dead || !state.started || state.winner_team != 0 {
		return
	}

	target, distance := nearest_enemy(state, unit^)
	if target == nil {
		return
	}

	d := max_f32(distance, 0.001)
	nx := (target.x - unit.x) / d
	ny := (target.y - unit.y) / d

	if unit.def.has_beam {
		desired: f32 = 0.18
		if d < unit.range * 0.62 {
			desired = -0.8
		} else if d > unit.range * 0.92 {
			desired = 0.6
		}
		unit.vx += nx * unit.speed * desired * dt
		unit.vy += ny * unit.speed * desired * dt
		update_beam(state, unit, target, d, nx, ny, dt)
	} else if unit.def.ai_spider {
		spider_behavior(state, unit, target, d, nx, ny, dt)
	} else {
		desired: f32 = 1
		if unit.def.ai_zoner {
			if d < unit.range * 0.62 {
				desired = -0.7
			} else if d > unit.range * 0.95 {
				desired = 0.75
			} else {
				desired = 0.08
			}
		}
		unit.vx += nx * unit.speed * desired * dt
		unit.vy += ny * unit.speed * desired * dt
		if d <= unit.range && unit.attack_timer <= 0 {
			unit.attack_timer = unit.cooldown
			attack(state, unit, target, nx, ny)
		}
	}

	if unit.webbed_time > 0 {
		unit.webbed_time = max_f32(0, unit.webbed_time - dt)
		wx := unit.web_anchor_x - unit.x
		wy := unit.web_anchor_y - unit.y
		wd := max_f32(vector_len(wx, wy), 0.001)
		unit.vx += (wx / wd) * 250 * dt
		unit.vy += (wy / wd) * 250 * dt
		if unit.webbed_time <= 0 {
			unit.webbed_by = 0
		}
	}

	unit.vy += state.gravity * dt
	unit.vx *= 0.995
	unit.vy *= 0.995
	unit.x += unit.vx * dt
	unit.y += unit.vy * dt

	if unit.x - unit.r < arena_left() + WALL {
		unit.x = arena_left() + WALL + unit.r
		unit.vx = abs_f32(unit.vx) * state.bounce
	}
	if unit.x + unit.r > arena_right() - WALL {
		unit.x = arena_right() - WALL - unit.r
		unit.vx = -abs_f32(unit.vx) * state.bounce
	}
	if unit.y - unit.r < arena_top() + WALL {
		unit.y = arena_top() + WALL + unit.r
		unit.vy = abs_f32(unit.vy) * state.bounce
	}
	if unit.y + unit.r > arena_bottom() - WALL {
		unit.y = arena_bottom() - WALL - unit.r
		unit.vy = -abs_f32(unit.vy) * state.bounce
	}
}

spider_behavior :: proc(state: ^Game_State, me: ^Unit, target: ^Unit, d, nx, ny, dt: f32) {
	webbed := target.webbed_by == me.uid && target.webbed_time > 0
	desired: f32 = -1.05
	if webbed {
		me.last_webbed_enemy_uid = target.uid
		me.last_webbed_enemy_timer = 1.2
		desired = 1.15
	} else if d > me.range * 0.82 {
		desired = 0.2
	}

	me.vx += nx * me.speed * desired * dt
	me.vy += ny * me.speed * desired * dt

	if !webbed && d <= me.range && me.attack_timer <= 0 {
		me.attack_timer = me.cooldown
		attack(state, me, target, nx, ny)
	}

	if webbed && d < me.r + target.r + 2 && me.attack_timer <= 0 {
		me.attack_timer = 0.35
		inflict_hit(state, me, target, nx, ny)
		target.webbed_time = 0
		target.webbed_by = 0
	}
}

update_beam :: proc(state: ^Game_State, me: ^Unit, target: ^Unit, d, nx, ny, dt: f32) {
	if d <= me.def.beam.range {
		if me.beam_target_uid != target.uid {
			me.beam_target_uid = target.uid
			me.beam_time = 0
		}
		me.beam_time += dt
		dps := f32(math.exp(f64(me.beam_time * me.def.beam.growth * 0.55))) * me.def.beam.base_dps
		apply_damage(state, target, dps * dt, me)
		target.vx += (nx * me.knockback * dt * 10) / target.mass
		target.vy += (ny * me.knockback * dt * 10) / target.mass
	} else {
		me.beam_target_uid = 0
		me.beam_time = 0
	}
}

update_statuses :: proc(state: ^Game_State, unit: ^Unit, dt: f32) {
	unit.attack_timer -= dt
	unit.helper_cooldown = max_f32(0, unit.helper_cooldown - dt)
	unit.helper_contact_cooldown = max_f32(0, unit.helper_contact_cooldown - dt)
	unit.stun = max_f32(0, unit.stun - dt)
	unit.burn = max_f32(0, unit.burn - dt)
	unit.poison = max_f32(0, unit.poison - dt)
	unit.last_webbed_enemy_timer = max_f32(0, unit.last_webbed_enemy_timer - dt)
	if unit.last_webbed_enemy_timer <= 0 {
		unit.last_webbed_enemy_uid = 0
	}
	if unit.burn > 0 {
		apply_damage(state, unit, unit.burn_dps * dt, nil)
	}
	if unit.poison > 0 {
		apply_damage(state, unit, unit.poison_dps * dt, nil)
	}
}

attack :: proc(state: ^Game_State, attacker, target: ^Unit, nx, ny: f32) {
	if attacker.def.has_trap {
		push_projectile(state, Projectile{
			kind = .Trap_Shot,
			owner_uid = attacker.uid,
			team = attacker.team,
			x = attacker.x + nx * (attacker.r + 6),
			y = attacker.y + ny * (attacker.r + 6),
			vx = nx * attacker.def.trap.projectile_speed,
			vy = ny * attacker.def.trap.projectile_speed,
			r = 10,
			life = 1.5,
			color = color_hex(0xc4b5fdff),
		})
		return
	}

	if attacker.def.has_web {
		push_projectile(state, Projectile{
			kind = .Web_Shot,
			owner_uid = attacker.uid,
			team = attacker.team,
			x = attacker.x + nx * (attacker.r + 4),
			y = attacker.y + ny * (attacker.r + 4),
			vx = nx * attacker.def.web.projectile_speed,
			vy = ny * attacker.def.web.projectile_speed,
			r = attacker.def.web.radius,
			life = 1.7,
			color = attacker.color,
		})
		return
	}

	inflict_hit(state, attacker, target, nx, ny)
}

inflict_hit :: proc(state: ^Game_State, attacker, target: ^Unit, nx, ny: f32) {
	apply_damage(state, target, attacker.damage, attacker)
	target.vx += (nx * attacker.knockback) / target.mass
	target.vy += (ny * attacker.knockback) / target.mass
	push_effect(state, Effect{
		kind = .Slash,
		x = (attacker.x + target.x) * 0.5,
		y = (attacker.y + target.y) * 0.5,
		nx = nx,
		ny = ny,
		life = 0.18,
		max_life = 0.18,
		color = attacker.color,
	})

	if attacker.def.has_poison {
		target.poison = attacker.def.poison.duration
		target.poison_dps = attacker.def.poison.dps
	}
	if attacker.def.has_infect {
		target.infected_by = attacker.uid
	}
	if attacker.def.has_web {
		target.poison = attacker.def.web.poison.duration
		target.poison_dps = attacker.def.web.poison.dps
	}
}

apply_damage :: proc(state: ^Game_State, target: ^Unit, amount: f32, source: ^Unit) {
	if target == nil || target.dead || amount <= 0 {
		return
	}

	on_unit_hit(state, target, source, amount)
	target.hp -= amount

	push_effect(state, Effect{
		kind = .Text,
		x = target.x,
		y = target.y - 24,
		life = 0.45,
		max_life = 0.45,
		color = rl.WHITE,
		text_value = amount,
	})

	if target.hp > 0 {
		return
	}

	if target.def.revive && !target.revived {
		target.revived = true
		target.hp = target.max_hp * 0.45
		push_effect(state, Effect{
			kind = .Ring,
			x = target.x,
			y = target.y,
			r = 10,
			max_r = 48,
			life = 0.6,
			max_life = 0.6,
			color = color_hex(0x84cc16ff),
		})
		return
	}

	death_x := target.x
	death_y := target.y
	target.dead = true
	target.hp = 0

	push_effect(state, Effect{
		kind = .Ring,
		x = death_x,
		y = death_y,
		r = 10,
		max_r = 54,
		life = 0.6,
		max_life = 0.6,
		color = target.color,
	})

	if target.infected_by != 0 && !target.is_helper {
		team := source_team_from_infection(state, target.infected_by, source)
		if team != 0 {
			baby := spawn_fighter(state, .Zombie, team, death_x, death_y, select_dir(), false, 0)
			if baby != nil {
				baby.name = "Infected Zombie"
				baby.hp = 52
				baby.max_hp = 52
				baby.r = 18
				baby.speed = 180
				baby.mass = 0.7
				baby.damage = 6
				baby.cooldown = 0.62
				baby.range = 38
				baby.knockback = 120
				baby.color = color_hex(0xbef264ff)
			}
		}
	}

	maybe_set_winner(state)
}

on_unit_hit :: proc(state: ^Game_State, target, source: ^Unit, amount: f32) {
	_ = source
	_ = amount
	if target.dead || !target.def.has_helpers {
		return
	}
	if target.helper_cooldown > 0 {
		return
	}
	target.helper_cooldown = target.def.helpers.cooldown
	spawn_helper_pair(state, target)
}

spawn_helper_pair :: proc(state: ^Game_State, larry: ^Unit) {
	offsets := [2]f32{-18, 18}
	for off in offsets {
		helper := spawn_fighter(state, .Sword, larry.team, larry.x + off, larry.y + off * 0.6, select_dir(), true, larry.uid)
		if helper == nil {
			continue
		}
		helper.vx += rand_range(-80, 80)
		helper.vy += rand_range(-80, 80)
		push_effect(state, Effect{
			kind = .Ring,
			x = helper.x,
			y = helper.y,
			r = 6,
			max_r = 18,
			life = 0.24,
			max_life = 0.24,
			color = helper.color,
		})
	}
}

resolve_pair_collision :: proc(state: ^Game_State, a, b: ^Unit) {
	if a.dead || b.dead {
		return
	}
	dx := b.x - a.x
	dy := b.y - a.y
	d := max_f32(vector_len(dx, dy), 0.001)
	min_d := a.r + b.r
	if d >= min_d {
		return
	}

	nx := dx / d
	ny := dy / d
	overlap := min_d - d
	a.x -= nx * overlap * 0.5
	a.y -= ny * overlap * 0.5
	b.x += nx * overlap * 0.5
	b.y += ny * overlap * 0.5

	dvx := b.vx - a.vx
	dvy := b.vy - a.vy
	rel := dvx * nx + dvy * ny
	if rel <= 0 {
		e: f32 = 0.92
		j := -(1 + e) * rel / (1 / a.mass + 1 / b.mass)
		ix := j * nx
		iy := j * ny
		a.vx -= ix / a.mass
		a.vy -= iy / a.mass
		b.vx += ix / b.mass
		b.vy += iy / b.mass
	}

	if a.team == b.team {
		return
	}

	if a.is_helper && a.helper_contact_cooldown <= 0 {
		a.helper_contact_cooldown = 0.15
		apply_damage(state, b, a.damage, a)
	}
	if b.is_helper && b.helper_contact_cooldown <= 0 {
		b.helper_contact_cooldown = 0.15
		apply_damage(state, a, b.damage, b)
	}
	if a.kind == .Spider && b.webbed_by == a.uid && !b.dead {
		inflict_hit(state, a, b, nx, ny)
		b.webbed_time = 0
		b.webbed_by = 0
	}
	if b.kind == .Spider && a.webbed_by == b.uid && !a.dead {
		inflict_hit(state, b, a, -nx, -ny)
		a.webbed_time = 0
		a.webbed_by = 0
	}
}

update_projectiles :: proc(state: ^Game_State, dt: f32) {
	i := 0
	for i < state.projectile_count {
		p := &state.projectiles[i]
		p.life -= dt
		p.x += p.vx * dt
		p.y += p.vy * dt

		hit_wall := p.x - p.r < arena_left() + WALL || p.x + p.r > arena_right() - WALL || p.y - p.r < arena_top() + WALL || p.y + p.r > arena_bottom() - WALL
		if hit_wall {
			owner := find_unit_by_uid(state, p.owner_uid)
			if owner != nil {
				if p.kind == .Trap_Shot {
					push_trap(state, Trap{
						kind = .Cage,
						owner_uid = owner.uid,
						team = owner.team,
						x = clamp_f32(p.x, arena_left() + 80, arena_right() - 80),
						y = clamp_f32(p.y, arena_top() + 80, arena_bottom() - 80),
						r = owner.def.trap.radius,
						life = owner.def.trap.life,
						max_life = owner.def.trap.life,
						wall_damage = owner.def.trap.wall_damage,
						wall_knock = owner.def.trap.wall_knock,
					})
				} else {
					push_trap(state, Trap{
						kind = .Web,
						owner_uid = owner.uid,
						team = owner.team,
						x = clamp_f32(p.x, arena_left() + 30, arena_right() - 30),
						y = clamp_f32(p.y, arena_top() + 30, arena_bottom() - 30),
						r = owner.def.web.trap_radius,
						life = owner.def.web.life,
						max_life = owner.def.web.life,
					})
				}
			}
			p.life = 0
		}

		if p.life <= 0 {
			remove_projectile(state, i)
		} else {
			i += 1
		}
	}
}

update_traps :: proc(state: ^Game_State, dt: f32) {
	i := 0
	for i < state.trap_count {
		t := &state.traps[i]
		t.life -= dt

		if t.kind == .Cage {
			for unit_index := 0; unit_index < state.unit_count; unit_index += 1 {
				u := &state.units[unit_index]
				if u.dead || u.team == t.team {
					continue
				}
				dx := u.x - t.x
				dy := u.y - t.y
				d := max_f32(vector_len(dx, dy), 0.001)
				if d < t.r - u.r {
					speed_sq := u.vx * u.vx + u.vy * u.vy
					if d > t.r - u.r - 8 && speed_sq > 2500 {
						nx := dx / d
						ny := dy / d
						u.x = t.x + nx * (t.r - u.r - 1)
						dot := u.vx * nx + u.vy * ny
						u.vx -= 2 * dot * nx
						u.vy -= 2 * dot * ny
						u.vx += nx * t.wall_knock / u.mass
						u.vy += ny * t.wall_knock / u.mass
						apply_damage(state, u, t.wall_damage, find_unit_by_uid(state, t.owner_uid))
					}
				}
			}
		} else {
			for unit_index := 0; unit_index < state.unit_count; unit_index += 1 {
				u := &state.units[unit_index]
				if u.dead || u.team == t.team {
					continue
				}
				if distance(u.x, u.y, t.x, t.y) < t.r + u.r {
					u.webbed_by = t.owner_uid
					u.webbed_time = 1.6
					u.web_anchor_x = t.x
					u.web_anchor_y = t.y
				}
			}
		}

		if t.life <= 0 {
			remove_trap(state, i)
		} else {
			i += 1
		}
	}
}

update_effects :: proc(state: ^Game_State, dt: f32) {
	i := 0
	for i < state.effect_count {
		state.effects[i].life -= dt
		if state.effects[i].life <= 0 {
			remove_effect(state, i)
		} else {
			i += 1
		}
	}
}

maybe_set_winner :: proc(state: ^Game_State) {
	if state.winner_team != 0 {
		return
	}
	alive_a := count_living_units(state, 1)
	alive_b := count_living_units(state, 2)
	if alive_a == 0 || alive_b == 0 {
		if alive_a > 0 {
			state.winner_team = 1
		} else if alive_b > 0 {
			state.winner_team = 2
		}
	}
}

nearest_enemy :: proc(state: ^Game_State, unit: Unit) -> (^Unit, f32) {
	best: ^Unit = nil
	best_d := f32(1e9)
	for i := 0; i < state.unit_count; i += 1 {
		other := &state.units[i]
		if other.dead || other.team == unit.team {
			continue
		}
		d := distance(unit.x, unit.y, other.x, other.y)
		if d < best_d {
			best_d = d
			best = other
		}
	}
	return best, best_d
}

count_living_units :: proc(state: ^Game_State, team: int) -> int {
	count := 0
	for i := 0; i < state.unit_count; i += 1 {
		if !state.units[i].dead && state.units[i].team == team {
			count += 1
		}
	}
	return count
}

find_unit_by_uid :: proc(state: ^Game_State, uid: int) -> ^Unit {
	for i := 0; i < state.unit_count; i += 1 {
		if state.units[i].uid == uid && !state.units[i].dead {
			return &state.units[i]
		}
	}
	return nil
}

source_team_from_infection :: proc(state: ^Game_State, infected_by: int, source: ^Unit) -> int {
	infector := find_unit_by_uid(state, infected_by)
	if infector != nil {
		return infector.team
	}
	if source != nil {
		return source.team
	}
	return 0
}

handle_ui :: proc(state: ^Game_State) {
	mouse := rl.GetMousePosition()
	mouse_pressed := rl.IsMouseButtonPressed(.LEFT)
	mouse_down := rl.IsMouseButtonDown(.LEFT)
	mouse_released := rl.IsMouseButtonReleased(.LEFT)

	if mouse_released {
		state.ui.active_slider = 0
	}

	left_dec := button(mouse, mouse_pressed, rect(24, 158, 36, 36), "<")
	left_inc := button(mouse, mouse_pressed, rect(272, 158, 36, 36), ">")
	right_dec := button(mouse, mouse_pressed, rect(24, 236, 36, 36), "<")
	right_inc := button(mouse, mouse_pressed, rect(272, 236, 36, 36), ">")

	if left_dec == .Pressed {
		state.fighter_a = cycle_kind(state.fighter_a, -1)
		reset_match(state)
	}
	if left_inc == .Pressed {
		state.fighter_a = cycle_kind(state.fighter_a, 1)
		reset_match(state)
	}
	if right_dec == .Pressed {
		state.fighter_b = cycle_kind(state.fighter_b, -1)
		reset_match(state)
	}
	if right_inc == .Pressed {
		state.fighter_b = cycle_kind(state.fighter_b, 1)
		reset_match(state)
	}

	slider_bounce := rect(24, 334, 284, 18)
	slider_gravity := rect(24, 404, 284, 18)
	slider_speed := rect(24, 474, 284, 18)

	update_slider(state, 1, slider_bounce, 0.6, 1.05, &state.bounce, mouse, mouse_pressed, mouse_down)
	update_slider(state, 2, slider_gravity, 0, 500, &state.gravity, mouse, mouse_pressed, mouse_down)
	update_slider(state, 3, slider_speed, 0.5, 2.5, &state.sim_speed, mouse, mouse_pressed, mouse_down)

	if button(mouse, mouse_pressed, rect(24, 540, 284, 42), "Start Fight") == .Pressed {
		state.started = true
	}
	if button(mouse, mouse_pressed, rect(24, 592, 284, 42), "Restart Match") == .Pressed {
		reset_match(state)
	}
}

draw_ui :: proc(state: ^Game_State) {
	draw_panel()

	draw_text("Weapon Ball Fight", 24, 28, 28, rl.WHITE)
	draw_text("Odin + raylib rewrite of the browser prototype.", 24, 62, 18, color_hex(0x9ca3afff))

	draw_section("Fighters", 24, 102)
	draw_fighter_picker(24, 130, "Left fighter", fighter_defs[int(state.fighter_a)].name)
	draw_fighter_picker(24, 208, "Right fighter", fighter_defs[int(state.fighter_b)].name)

	draw_section("Arena", 24, 290)
	draw_slider_block("Wall bounce", state.bounce, 24, 334, 0.6, 1.05, false)
	draw_slider_block("Gravity", state.gravity, 24, 404, 0, 500, true)
	draw_slider_block("Sim speed", state.sim_speed, 24, 474, 0.5, 2.5, false)

	draw_button_visual(rect(24, 540, 284, 42), "Start Fight", color_hex(0x22c55eff), color_hex(0x08110cff))
	draw_button_visual(rect(24, 592, 284, 42), "Restart Match", color_hex(0x60a5faff), color_hex(0x08111fff))

	draw_text("Space / Enter starts the match.", 24, 650, 18, color_hex(0xd1d5dbff))
	draw_text("Trapper fires cage shots.", 24, 682, 16, color_hex(0x9ca3afff))
	draw_text("Spider webs, retreats, then dives in.", 24, 704, 16, color_hex(0x9ca3afff))
	draw_text("Zombie revives and spreads infection.", 24, 726, 16, color_hex(0x9ca3afff))
}

draw_arena :: proc(state: ^Game_State) {
	rl.DrawRectangleRounded(rect(ARENA_X, ARENA_Y, ARENA_W, ARENA_H), 0.03, 12, color_hex(0x0b1220ff))
	rl.DrawRectangleLinesEx(rect(ARENA_X, ARENA_Y, ARENA_W, ARENA_H), 1, color_hex(0x374151ff))

	for stripe := 0; stripe < 12; stripe += 1 {
		alpha := u8(5)
		if stripe % 2 == 0 {
			alpha = 8
		}
		w := ARENA_W / 12
		rl.DrawRectangleV(
			vec2(ARENA_X + f32(stripe) * w, ARENA_Y),
			vec2(w, ARENA_H),
			rl.Color{255, 255, 255, alpha},
		)
	}

	rl.DrawRectangleLinesEx(rect(arena_left() + WALL, arena_top() + WALL, ARENA_W - WALL * 2, ARENA_H - WALL * 2), 3, color_hex(0x334155ff))

	for i := 0; i < state.trap_count; i += 1 {
		draw_trap(&state.traps[i])
	}
	for i := 0; i < state.projectile_count; i += 1 {
		draw_projectile(&state.projectiles[i])
	}
	for i := 0; i < state.unit_count; i += 1 {
		draw_beam(state, &state.units[i])
	}
	for i := 0; i < state.unit_count; i += 1 {
		draw_unit(state, &state.units[i])
	}
	for i := 0; i < state.effect_count; i += 1 {
		draw_effect(&state.effects[i])
	}

	draw_hud(state)
	if !state.started {
		draw_ready_box()
	}
	if state.winner_team != 0 {
		draw_winner_box(state)
	}
}

draw_hud :: proc(state: ^Game_State) {
	left_primary := primary_unit(state, 1)
	right_primary := primary_unit(state, 2)

	draw_hud_card(rect(ARENA_X + 20, ARENA_Y + 20, 300, 74), left_primary, false)
	draw_hud_card(rect(ARENA_X + ARENA_W - 320, ARENA_Y + 20, 300, 74), right_primary, true)
}

draw_hud_card :: proc(bounds: rl.Rectangle, unit: ^Unit, align_right: bool) {
	rl.DrawRectangleRounded(bounds, 0.14, 10, rgba(17, 24, 39, 220))
	rl.DrawRectangleLinesEx(bounds, 1, color_hex(0x374151ff))

	name := "Unknown"
	status := ""
	fill := color_hex(0x60a5faff)
	hp_pct: f32 = 0

	if unit != nil {
		name = unit.name
		fill = unit.color
		hp_pct = clamp_f32(unit.hp / max_f32(unit.max_hp, 1), 0, 1)
		status = status_text(unit^)
	}

	text_x := i32(bounds.x + 14)
	if align_right {
		text_x = i32(bounds.x + bounds.width - 14 - f32(text_width(name, 20)))
	}

	draw_text(name, text_x, i32(bounds.y + 12), 20, rl.WHITE)
	bar_rect := rect(bounds.x + 14, bounds.y + 38, bounds.width - 28, 12)
	rl.DrawRectangleRounded(bar_rect, 1, 8, color_hex(0x374151ff))
	rl.DrawRectangleRounded(rect(bar_rect.x, bar_rect.y, bar_rect.width * hp_pct, bar_rect.height), 1, 8, fill)
	draw_text(status, i32(bounds.x + 14), i32(bounds.y + 54), 16, color_hex(0xd1d5dbff))
}

draw_ready_box :: proc() {
	box := rect(ARENA_X + ARENA_W * 0.5 - 180, ARENA_Y + ARENA_H * 0.5 - 54, 360, 108)
	rl.DrawRectangleRounded(box, 0.14, 10, rgba(17, 24, 39, 238))
	rl.DrawRectangleLinesEx(box, 1, color_hex(0x4b5563ff))
	draw_text("Ready to fight", i32(box.x + 84), i32(box.y + 24), 28, rl.WHITE)
	draw_text("Press Start Fight or hit Space.", i32(box.x + 52), i32(box.y + 60), 18, color_hex(0xd1d5dbff))
}

draw_winner_box :: proc(state: ^Game_State) {
	label := fmt.tprintf("%s wins", team_name(state, state.winner_team))
	w := f32(text_width(label, 24) + 40)
	box := rect(ARENA_X + ARENA_W * 0.5 - w * 0.5, ARENA_Y + ARENA_H - 70, w, 42)
	rl.DrawRectangleRounded(box, 1, 8, rgba(17, 24, 39, 235))
	rl.DrawRectangleLinesEx(box, 1, color_hex(0x374151ff))
	draw_text(label, i32(box.x + 20), i32(box.y + 10), 24, rl.WHITE)
}

draw_unit :: proc(state: ^Game_State, unit: ^Unit) {
	if unit.dead {
		return
	}
	rl.DrawCircleV(vec2(unit.x, unit.y), unit.r, unit.color)
	rl.DrawCircleV(vec2(unit.x - unit.r * 0.25, unit.y - unit.r * 0.25), unit.r * 0.35, rgba(255, 255, 255, 60))

	if unit.webbed_time > 0 {
		rl.DrawLineEx(vec2(unit.x, unit.y), vec2(unit.web_anchor_x, unit.web_anchor_y), 2, color_hex(0xf472b6ff))
	}

	if unit.kind == .Sword || unit.kind == .Toxic || unit.kind == .Zombie || unit.kind == .Larry || unit.is_helper {
		target, _ := nearest_enemy(state, unit^)
		if target != nil {
			dx := target.x - unit.x
			dy := target.y - unit.y
			d := max_f32(vector_len(dx, dy), 0.001)
			nx := dx / d
			ny := dy / d
			color := rl.WHITE
			thickness: f32 = 4
			if unit.kind == .Toxic {
				color = color_hex(0xbbf7d0ff)
			}
			if unit.kind == .Larry {
				thickness = 6
			}
			rl.DrawLineEx(
				vec2(unit.x + nx * unit.r * 0.7, unit.y + ny * unit.r * 0.7),
				vec2(unit.x + nx * (unit.r + 16), unit.y + ny * (unit.r + 16)),
				thickness,
				color,
			)
		}
	}
}

draw_beam :: proc(state: ^Game_State, unit: ^Unit) {
	if unit.dead || !unit.def.has_beam || unit.beam_target_uid == 0 || unit.beam_time <= 0 {
		return
	}
	target := find_unit_by_uid(state, unit.beam_target_uid)
	if target == nil {
		return
	}
	if distance(unit.x, unit.y, target.x, target.y) > unit.def.beam.range {
		return
	}
	alpha := clamp_f32(0.25 + unit.beam_time * 0.3, 0.25, 0.95)
	width := clamp_f32(3 + unit.beam_time * 2.2, 3, 12)
	rl.DrawLineEx(vec2(unit.x, unit.y), vec2(target.x, target.y), width, color_alpha(color_hex(0xfb923cff), alpha))
}

draw_projectile :: proc(p: ^Projectile) {
	rl.DrawCircleV(vec2(p.x, p.y), p.r, p.color)
}

draw_trap :: proc(t: ^Trap) {
	alpha := 0.35 + 0.45 * (t.life / max_f32(t.max_life, 0.001))
	if t.kind == .Cage {
		rl.DrawRing(vec2(t.x, t.y), t.r - 3, t.r + 3, 0, 360, 64, color_alpha(color_hex(0xc4b5fdff), alpha))
		return
	}

	color := color_alpha(color_hex(0xf472b6ff), alpha)
	for i := 0; i < 6; i += 1 {
		a := f32(i) * f32(math.PI) * 2 / 6
		x := t.x + math.cos_f32(a) * t.r
		y := t.y + math.sin_f32(a) * t.r
		rl.DrawLineEx(vec2(t.x, t.y), vec2(x, y), 2, color)
	}
	rl.DrawCircleLinesV(vec2(t.x, t.y), t.r * 0.35, color)
	rl.DrawCircleLinesV(vec2(t.x, t.y), t.r * 0.72, color)
}

draw_effect :: proc(effect: ^Effect) {
	alpha := clamp_f32(effect.life / max_f32(effect.max_life, 0.001), 0, 1)
	switch effect.kind {
	case .Ring:
		p := 1 - effect.life / max_f32(effect.max_life, 0.001)
		rr := effect.r + (effect.max_r - effect.r) * clamp_f32(p, 0, 1)
		rl.DrawRing(vec2(effect.x, effect.y), rr - 1.5, rr + 1.5, 0, 360, 64, color_alpha(effect.color, alpha))
	case .Slash:
		start := vec2(effect.x - effect.nx * 10 - effect.ny * 8, effect.y - effect.ny * 10 + effect.nx * 8)
		finish := vec2(effect.x + effect.nx * 10 + effect.ny * 8, effect.y + effect.ny * 10 - effect.nx * 8)
		rl.DrawLineEx(start, finish, 4, color_alpha(effect.color, alpha))
	case .Text:
		label := fmt.tprintf("%.1f", effect.text_value)
		draw_text(label, i32(effect.x), i32(effect.y - (1 - alpha) * 18), 18, color_alpha(effect.color, alpha))
	}
}

draw_panel :: proc() {
	rl.DrawRectangle(0, 0, PANEL_W, SCREEN_H, color_hex(0x1f2937ff))
	rl.DrawLine(PANEL_W, 0, PANEL_W, SCREEN_H, color_hex(0x374151ff))
}

draw_section :: proc(label: string, x, y: i32) {
	draw_text(label, x, y, 22, rl.WHITE)
}

draw_fighter_picker :: proc(x, y: i32, label, value: string) {
	draw_text(label, x, y, 16, color_hex(0xd1d5dbff))
	draw_button_visual(rect(f32(x), f32(y + 28), 36, 36), "<", color_hex(0x111827ff), rl.WHITE)
	draw_button_visual(rect(f32(x + 248), f32(y + 28), 36, 36), ">", color_hex(0x111827ff), rl.WHITE)
	box := rect(f32(x + 44), f32(y + 28), 196, 36)
	rl.DrawRectangleRounded(box, 0.2, 8, color_hex(0x111827ff))
	rl.DrawRectangleLinesEx(box, 1, color_hex(0x4b5563ff))
	text_w := text_width(value, 18)
	draw_text(value, i32(box.x + box.width * 0.5 - f32(text_w) * 0.5), i32(box.y + 9), 18, rl.WHITE)
}

draw_slider_block :: proc(label: string, value: f32, x, y: i32, min_value, max_value: f32, whole_number: bool) {
	draw_text(label, x, y - 26, 16, color_hex(0xd1d5dbff))
	bar := rect(f32(x), f32(y), 284, 18)
	rl.DrawRectangleRounded(bar, 1, 8, color_hex(0x374151ff))
	pct := clamp_f32((value - min_value) / (max_value - min_value), 0, 1)
	fill := rect(bar.x, bar.y, bar.width * pct, bar.height)
	rl.DrawRectangleRounded(fill, 1, 8, color_hex(0x60a5faff))
	knob_x := bar.x + bar.width * pct
	rl.DrawCircleV(vec2(knob_x, bar.y + bar.height * 0.5), 10, rl.WHITE)
	value_label := ""
	if whole_number {
		value_label = fmt.tprintf("%.0f", value)
	} else if max_value <= 2.5 {
		value_label = fmt.tprintf("%.1fx", value)
	} else {
		value_label = fmt.tprintf("%.2f", value)
	}
	draw_text(value_label, x + 236, y - 28, 16, color_hex(0xd1d5dbff))
}

draw_button_visual :: proc(bounds: rl.Rectangle, label: string, bg, fg: rl.Color) {
	rl.DrawRectangleRounded(bounds, 0.22, 8, bg)
	rl.DrawRectangleLinesEx(bounds, 1, color_hex(0x4b5563ff))
	text_w := text_width(label, 18)
	draw_text(label, i32(bounds.x + bounds.width * 0.5 - f32(text_w) * 0.5), i32(bounds.y + 9), 18, fg)
}

button :: proc(mouse: rl.Vector2, mouse_pressed: bool, bounds: rl.Rectangle, label: string) -> Button_Result {
	_ = label
	if rl.CheckCollisionPointRec(mouse, bounds) {
		if mouse_pressed {
			return .Pressed
		}
		return .Hovered
	}
	return .None
}

update_slider :: proc(state: ^Game_State, slider_id: int, bounds: rl.Rectangle, min_value, max_value: f32, value: ^f32, mouse: rl.Vector2, mouse_pressed, mouse_down: bool) {
	hovered := rl.CheckCollisionPointRec(mouse, rect(bounds.x - 4, bounds.y - 10, bounds.width + 8, bounds.height + 20))
	if hovered && mouse_pressed {
		state.ui.active_slider = slider_id
	}
	if state.ui.active_slider != slider_id || !mouse_down {
		return
	}
	pct := clamp_f32((mouse.x - bounds.x) / bounds.width, 0, 1)
	value^ = min_value + pct * (max_value - min_value)
	if slider_id == 1 {
		value^ = f32(math.round(f64(value^ * 100))) / 100
	}
	if slider_id == 2 {
		value^ = f32(math.round(f64(value^ / 10))) * 10
	}
	if slider_id == 3 {
		value^ = f32(math.round(f64(value^ * 10))) / 10
	}
}

primary_unit :: proc(state: ^Game_State, team: int) -> ^Unit {
	for i := 0; i < state.unit_count; i += 1 {
		unit := &state.units[i]
		if !unit.dead && !unit.is_helper && unit.team == team {
			return unit
		}
	}
	for i := 0; i < state.unit_count; i += 1 {
		unit := &state.units[i]
		if !unit.dead && unit.team == team {
			return unit
		}
	}
	return nil
}

status_text :: proc(unit: Unit) -> string {
	tags := [4]Status_Tag{
		{"Burn", unit.burn > 0},
		{"Poison", unit.poison > 0},
		{"Revived", unit.revived},
		{"Webbed", unit.webbed_time > 0},
	}

	result := ""
	first := true
	for tag in tags {
		if !tag.active {
			continue
		}
		if !first {
			result = fmt.tprintf("%s, %s", result, tag.label)
		} else {
			result = tag.label
		}
		first = false
	}
	return result
}

team_name :: proc(state: ^Game_State, team: int) -> string {
	unit := primary_unit(state, team)
	if unit != nil {
		return unit.name
	}
	if team == 1 {
		return "Left fighter"
	}
	return "Right fighter"
}

push_projectile :: proc(state: ^Game_State, projectile: Projectile) {
	if state.projectile_count >= MAX_PROJECTILES {
		return
	}
	state.projectiles[state.projectile_count] = projectile
	state.projectile_count += 1
}

push_trap :: proc(state: ^Game_State, trap: Trap) {
	if state.trap_count >= MAX_TRAPS {
		return
	}
	state.traps[state.trap_count] = trap
	state.trap_count += 1
}

push_effect :: proc(state: ^Game_State, effect: Effect) {
	if state.effect_count >= MAX_EFFECTS {
		return
	}
	state.effects[state.effect_count] = effect
	state.effect_count += 1
}

remove_projectile :: proc(state: ^Game_State, index: int) {
	state.projectile_count -= 1
	state.projectiles[index] = state.projectiles[state.projectile_count]
}

remove_trap :: proc(state: ^Game_State, index: int) {
	state.trap_count -= 1
	state.traps[index] = state.traps[state.trap_count]
}

remove_effect :: proc(state: ^Game_State, index: int) {
	state.effect_count -= 1
	state.effects[index] = state.effects[state.effect_count]
}

cycle_kind :: proc(kind: Fighter_Kind, delta: int) -> Fighter_Kind {
	count := len(fighter_defs)
	next := (int(kind) + delta + count) % count
	return Fighter_Kind(next)
}

arena_left :: proc() -> f32 { return ARENA_X }
arena_right :: proc() -> f32 { return ARENA_X + ARENA_W }
arena_top :: proc() -> f32 { return ARENA_Y }
arena_bottom :: proc() -> f32 { return ARENA_Y + ARENA_H }

distance :: proc(ax, ay, bx, by: f32) -> f32 {
	return vector_len(ax - bx, ay - by)
}

vector_len :: proc(x, y: f32) -> f32 {
	return f32(math.sqrt(f64(x * x + y * y)))
}

rand_seed: u32 = 0x12345678

rand_u32 :: proc() -> u32 {
	rand_seed = rand_seed * 1664525 + 1013904223
	return rand_seed
}

rand_range :: proc(min_value, max_value: f32) -> f32 {
	pct := f32(rand_u32() & 0x00ffffff) / f32(0x00ffffff)
	return min_value + (max_value - min_value) * pct
}

select_dir :: proc() -> f32 {
	if (rand_u32() & 1) == 0 {
		return -1
	}
	return 1
}

vec2 :: proc(x, y: f32) -> rl.Vector2 {
	return rl.Vector2{x, y}
}

rect :: proc(x, y, w, h: f32) -> rl.Rectangle {
	return rl.Rectangle{x, y, w, h}
}

draw_text :: proc(text: string, x, y, size: i32, color: rl.Color) {
	rl.DrawText(strings.clone_to_cstring(text, context.temp_allocator), x, y, size, color)
}

text_width :: proc(text: string, size: i32) -> i32 {
	return rl.MeasureText(strings.clone_to_cstring(text, context.temp_allocator), size)
}

color_hex :: proc(v: u32) -> rl.Color {
	return rl.Color{
		u8((v >> 24) & 0xff),
		u8((v >> 16) & 0xff),
		u8((v >> 8) & 0xff),
		u8(v & 0xff),
	}
}

rgba :: proc(r, g, b, a: u8) -> rl.Color {
	return rl.Color{r, g, b, a}
}

color_alpha :: proc(color: rl.Color, alpha: f32) -> rl.Color {
	return rl.Color{
		color.r,
		color.g,
		color.b,
		u8(clamp_f32(alpha, 0, 1) * 255),
	}
}

clamp_f32 :: proc(v, min_value, max_value: f32) -> f32 {
	if v < min_value {
		return min_value
	}
	if v > max_value {
		return max_value
	}
	return v
}

min_f32 :: proc(a, b: f32) -> f32 {
	if a < b {
		return a
	}
	return b
}

max_f32 :: proc(a, b: f32) -> f32 {
	if a > b {
		return a
	}
	return b
}

abs_f32 :: proc(v: f32) -> f32 {
	if v < 0 {
		return -v
	}
	return v
}
