extends CharacterBody3D

enum State { IDLE, MOVE, ATTACK, SYNTHESIS, DAMAGED }
var current_state: State = State.IDLE

@export var speed: float = 5.0
@export var acceleration: float = 15.0

@onready var sprite: AnimatedSprite3D = get_node_or_null("AnimatedSprite3D")
var facing_direction: Vector2 = Vector2.DOWN

signal state_changed(old_state: State, new_state: State)
signal synthesis_requested

func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	match current_state:
		State.IDLE:
			_handle_idle_state(input_vector)
		State.MOVE:
			_handle_move_state(input_vector, delta)
		State.ATTACK:
			# アタック中は移動不可
			velocity = velocity.move_toward(Vector3.ZERO, acceleration * delta)
			move_and_slide()
		State.SYNTHESIS:
			# 培養槽内演出中は移動不可
			velocity = Vector3.ZERO
		State.DAMAGED:
			velocity = velocity.move_toward(Vector3.ZERO, acceleration * delta)
			move_and_slide()

	# 攻撃キーの入力受付
	if Input.is_action_just_pressed("action_attack") and current_state in [State.IDLE, State.MOVE]:
		change_state(State.ATTACK)

	# 合成キーの入力受付
	if Input.is_action_just_pressed("action_synthesize") and current_state == State.IDLE:
		synthesis_requested.emit()

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)

	match current_state:
		State.ATTACK:
			_play_anim("attack_" + _get_facing_suffix())
			if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
				sprite.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)
		State.SYNTHESIS:
			_play_anim("synthesis_idle")
		State.DAMAGED:
			_play_anim("damaged_" + _get_facing_suffix())
			if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
				sprite.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)

func _handle_idle_state(input: Vector2) -> void:
	if input != Vector2.ZERO:
		change_state(State.MOVE)
		return
	_play_anim("idle_" + _get_facing_suffix())

func _handle_move_state(input: Vector2, delta: float) -> void:
	if input == Vector2.ZERO:
		change_state(State.IDLE)
		return

	facing_direction = input.normalized()

	var direction := Vector3(input.x, 0.0, input.y).normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	move_and_slide()

	_play_anim("walk_" + _get_facing_suffix())

	if sprite and facing_direction.x != 0:
		sprite.flip_h = (facing_direction.x < 0)

func _get_facing_suffix() -> String:
	if abs(facing_direction.x) > abs(facing_direction.y):
		return "side"
	return "down" if facing_direction.y > 0 else "up"

func _play_anim(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

func _on_animation_finished() -> void:
	if current_state in [State.ATTACK, State.DAMAGED]:
		change_state(State.IDLE)
