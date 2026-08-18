extends CharacterBody3D

@export var speed: float = 5.0
@export var acceleration: float = 15.0

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

# 入力ベクトルの定義
var input_dir: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	# 入力の取得
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# 3D空間への変換 (X-Z平面上の移動)
	var direction := Vector3(input_vector.x, 0.0, input_vector.y).normalized()

	if direction != Vector3.ZERO:
		# なめらかな加速
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)

		# 移動アニメーションの適用
		_update_animation(input_vector, true)
	else:
		# 摩擦によるなめらかな減速
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

		# 待機アニメーションの適用
		_update_animation(input_vector, false)

	# 重力の適用
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	move_and_slide()

# アニメーション切り替えロジック
func _update_animation(dir: Vector2, is_moving: bool) -> void:
	if not sprite:
		return

	var anim_prefix = "walk_" if is_moving else "idle_"
	var suffix = "down"

	# 簡易4方向判定
	if dir != Vector2.ZERO:
		if abs(dir.x) > abs(dir.y):
			if dir.x > 0:
				suffix = "side"
				sprite.flip_h = false # 右向き
			else:
				suffix = "side"
				sprite.flip_h = true  # 左向き (反転)
		else:
			if dir.y > 0:
				suffix = "down"
			else:
				suffix = "up"

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_prefix + suffix):
		sprite.play(anim_prefix + suffix)
