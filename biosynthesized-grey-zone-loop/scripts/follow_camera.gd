extends Camera3D

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 8, 8) # 斜め上からのオフセット
@export var smooth_speed: float = 5.0

# カメラシェイク用パラメータ
var shake_amount: float = 0.0
var shake_decay: float = 5.0
var rng = RandomNumberGenerator.new()

var target: Node3D = null

func _ready() -> void:
	rng.randomize()
	if target_path:
		target = get_node_or_null(target_path) as Node3D

	# 初期位置の設定とターゲットの方向を向く
	if target:
		global_position = target.global_position + offset
		look_at(target.global_position, Vector3.UP)

func _physics_process(delta: float) -> void:
	if not target:
		return

	# ターゲット位置にオフセットを加えた目標位置
	var target_pos = target.global_position + offset

	# 線形補間(Lerp)によるなめらかな追従
	global_position = global_position.lerp(target_pos, smooth_speed * delta)

	# カメラシェイク効果の減衰と適用
	if shake_amount > 0:
		shake_amount = max(shake_amount - shake_decay * delta, 0)
		var offset_shake = Vector3(
			rng.randf_range(-shake_amount, shake_amount),
			rng.randf_range(-shake_amount, shake_amount),
			rng.randf_range(-shake_amount, shake_amount)
		)
		global_position += offset_shake

func add_shake(amount: float) -> void:
	shake_amount = amount
