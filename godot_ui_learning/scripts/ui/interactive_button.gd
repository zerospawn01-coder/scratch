extends Button

func _ready() -> void:
	# 拡縮の中心をボタンの中央に設定
	pivot_offset = size / 2.0
	
	# リサイズ時にもピボットを中央に維持する
	resized.connect(func(): pivot_offset = size / 2.0)
	
	# シグナルの接続
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_mouse_entered() -> void:
	var tween = create_tween().set_parallel(true)
	# 滑らかに1.05倍へ拡大
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	var tween = create_tween().set_parallel(true)
	# 元のサイズに戻す
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_button_down() -> void:
	var tween = create_tween().set_parallel(true)
	# 押し込み表現として少し縮小する
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_button_up() -> void:
	var tween = create_tween().set_parallel(true)
	# 押下終了時、まだマウスが乗っていればホバー時のサイズ(1.05)へ、外れていれば1.0へ
	var target_scale = Vector2(1.05, 1.05) if is_hovered() else Vector2(1.0, 1.0)
	tween.tween_property(self, "scale", target_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
