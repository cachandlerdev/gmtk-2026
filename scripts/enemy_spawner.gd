extends Node2D


enum Type {Infinite, FixedNumberOfEnemies, MaxNumberOfEnemies}


@export_group("Spawn Settings")
## Determines whether the spawner can start firing immediately, or whether it 
## should wait for a specified command
@export var spawn_right_away: bool = false
## Starts spawning when the alarm has been raised on when the player is trying 
## to escape 
@export var spawn_on_alarm: bool = false

## The spawn type to use. 
## Infinite means that an infinite number of enemies can be spawned, each one 
## at a periodic time interval. 
## FixedNumberOfEnemies means that the spawner will spawn in X number of enemies
## and then not spawn anything more.
## MaxNumberOfEnemies means that the spawner is allowed to have a maximum of X
## enemies alive at once, but after an enemy dies, it can spawn in 1 more.
@export var spawn_type = Type.Infinite
## The amount of time that the spawner will wait between trying to spawn
@export var spawn_cooldown: float = 10.0
## When using FixedNumberOfEnemies, this is the max number that the spawner can
## ever spawn unless it is reset. When using MaxNumberOfEnemies, this is the max
## count that can be alive at one time.
@export var number_of_enemies: int = 5
## Specifies the type of enemy to spawn
@export_file var enemy_prototype: String

## Controls when to start spawning
var _should_spawn: bool

## A ref to the spawned enemies. Only matters for FixedNumberOfEnemies
var _enemies_spawned = []
## The number of enemies that have been spawned. Only matters for MaxNumberOfEnemies
var _number_of_enemies_spawned: int = 0


@onready var cooldown_timer: Timer = $CooldownTimer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_should_spawn = spawn_right_away
	cooldown_timer.wait_time = spawn_cooldown
	cooldown_timer.start()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


## Tell the spawner that it should start spitting out enemies
func start_spawning() -> void:
	_should_spawn = true


## Returns whether the settings allow an enemy to be spawned now
func can_spawn() -> bool:
	return spawn_type == Type.Infinite or (
		spawn_type == Type.FixedNumberOfEnemies and 
		_number_of_enemies_spawned < number_of_enemies) or (
			spawn_type == Type.MaxNumberOfEnemies and 
			_enemies_spawned.size() < number_of_enemies
		)


## Reset the properties for this spawner. (e.g. it used up its 5 enemies, but
## we're resetting it so it can spawn all 5 back in again.)
## This does not affect the lifespan of existing spawned enemies
func reset_spawn_properties() -> void:
	_number_of_enemies_spawned = 0
	_enemies_spawned.clear()


## Cooldown ended. Spawn an enemy if possible
func _on_cooldown_timer_timeout() -> void:
	if spawn_on_alarm and (GameMode.get_state() == GameMode.AlarmRaised or GameMode.get_state() == GameMode.Escape):
		_should_spawn = true
	
	var live_enemies_spawned = []
	for enemy in _enemies_spawned:
		if enemy:
			live_enemies_spawned.append(enemy)
	_enemies_spawned = live_enemies_spawned

	if can_spawn() and _should_spawn:
		_spawn_enemy()


## Spawn the enemy
func _spawn_enemy() -> void:
	print("spawn_enemy")
	var new_enemy = load(enemy_prototype).instantiate()

	get_tree().current_scene.add_child((new_enemy))
	new_enemy.global_position = global_position
	new_enemy.global_position.y += -20
	new_enemy.scale = Vector2(1.0, 1.0)
	_number_of_enemies_spawned += 1
	_enemies_spawned.append(new_enemy)
	
