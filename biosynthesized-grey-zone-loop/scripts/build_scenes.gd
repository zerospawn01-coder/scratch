@tool
extends SceneTree

const PIXELS_PER_UNIT: float = 26.0

func _init():
	print("=== Starting Canonical Containment Scene Build ===")
	DirAccess.make_dir_recursive_absolute("res://scenes")

	_build_investigator_player_scene()
	_build_ally_bioroid_scene()
	_build_enemy_bioroid_scene()
	_build_bioroid_pod_scene()
	_build_exploration_scene()
	_build_arena_battle_scene()
	_build_gene_mixer_scene()
	_build_main_terminal_scene()

	print("=== Canonical Containment Scenes Built Successfully ===")
	quit(0)

# ────────────────────────────────────────────
func _save(node: Node, path: String) -> void:
	var packed = PackedScene.new()
	if packed.pack(node) == OK:
		if ResourceSaver.save(packed, path) == OK:
			print("  [OK] Saved Scene: ", path)
		else:
			printerr("  [FAIL] Could not save resource: ", path)
	else:
		printerr("  [FAIL] Could not pack scene: ", path)

# ────────────────────────────────────────────
func _make_sprite(tex_path: String, frame_w: int, frame_h: int,
				  anim_names: Array, fps: float = 6.0) -> AnimatedSprite3D:
	var s = AnimatedSprite3D.new()
	s.name = "AnimatedSprite3D"
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.billboard      = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.cast_shadow    = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	s.alpha_cut      = AnimatedSprite3D.ALPHA_CUT_DISCARD
	s.pixel_size     = 1.0 / PIXELS_PER_UNIT
	s.position       = Vector3(0, float(frame_h) / (2.0 * PIXELS_PER_UNIT), 0)

	var frames = SpriteFrames.new()
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path) as Texture2D

	for i in range(anim_names.size()):
		var aname = anim_names[i]
		if not frames.has_animation(aname):
			frames.add_animation(aname)
		frames.set_animation_loop(aname, true)
		frames.set_animation_speed(aname, fps)
		if tex:
			var atlas = AtlasTexture.new()
			atlas.atlas  = tex
			atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
			frames.add_frame(aname, atlas)

	s.sprite_frames = frames
	if frames.has_animation(anim_names[0]):
		s.play(anim_names[0])
	return s

# ────────────────────────────────────────────
func _make_capsule_col(radius: float, height: float, y_offset: float) -> CollisionShape3D:
	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape = CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape    = shape
	col.position = Vector3(0, y_offset, 0)
	return col

# ────────────────────────────────────────────
# 1. 探索用 調査員
# ────────────────────────────────────────────
func _build_investigator_player_scene() -> void:
	var root = CharacterBody3D.new()
	root.name = "Investigator"
	root.set_script(load("res://scripts/investigator_fsm.gd"))

	var sprite = _make_sprite(
		"res://assets/investigator_spritesheet.png",
		64, 64,
		["idle_down", "walk_down", "idle_side", "walk_side", "idle_up", "walk_up"]
	)
	root.add_child(sprite); sprite.owner = root

	var col = _make_capsule_col(0.4, 2.0, 1.0)
	root.add_child(col); col.owner = root

	_save(root, "res://scenes/investigator_player.tscn")

# ────────────────────────────────────────────
# 2. 味方バイオロイド (BIO-ALD-DEF001 [ALDEN])
# 高解像度スプライト + 神経回路/培養コア微発光
# ────────────────────────────────────────────
func _build_ally_bioroid_scene() -> void:
	var root = CharacterBody3D.new()
	root.name = "AllyBioroid"

	var sprite_path = "res://assets/bioroids/sprites/type1_clean_ceramic_front_combat.png"
	var sprite = Sprite3D.new()
	sprite.name = "BioroidSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.transparent = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	if ResourceLoader.exists(sprite_path):
		var tex = load(sprite_path) as Texture2D
		sprite.texture = tex
		# Target height: 3.4 units
		sprite.pixel_size = 3.4 / float(tex.get_height())
		sprite.position = Vector3(0, 1.7, 0)
	else:
		push_error("[Aether Fountain] Missing bioroid texture: " + sprite_path)

	root.add_child(sprite); sprite.owner = root

	# 胸部培養コアの微発光 OmniLight3D (Teal/Cyan)
	var core_light = OmniLight3D.new()
	core_light.name = "CoreGlowLight"
	core_light.light_color = Color(0.1, 0.95, 0.85)
	core_light.light_energy = 1.8
	core_light.omni_range = 3.2
	core_light.position = Vector3(0, 2.1, 0.2)
	root.add_child(core_light); core_light.owner = root

	var col = _make_capsule_col(0.5, 3.4, 1.7)
	root.add_child(col); col.owner = root

	_save(root, "res://scenes/ally_bioroid.tscn")

# ────────────────────────────────────────────
# 3. 敵性変異バイオロイド (SUBJECT AF-09 [LAMBDA ANOMALY])
# 高解像度スプライト + 暴走赤色生体核発光
# ────────────────────────────────────────────
func _build_enemy_bioroid_scene() -> void:
	var root = CharacterBody3D.new()
	root.name = "EnemyBioroid"

	var sprite_path = "res://assets/bioroids/sprites/type4_corrupted_anomaly_front_combat.png"
	var sprite = Sprite3D.new()
	sprite.name = "BioroidSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.transparent = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	if ResourceLoader.exists(sprite_path):
		var tex = load(sprite_path) as Texture2D
		sprite.texture = tex
		# Target height: 3.8 units (1.12x of Alden)
		sprite.pixel_size = 3.8 / float(tex.get_height())
		sprite.position = Vector3(0, 1.9, 0)
	else:
		push_error("[Aether Fountain] Missing bioroid texture: " + sprite_path)

	root.add_child(sprite); sprite.owner = root

	# 暴走生体核の脈動赤光 OmniLight3D (Crimson/Red)
	var core_light = OmniLight3D.new()
	core_light.name = "AnomalyCoreGlowLight"
	core_light.light_color = Color(1.0, 0.12, 0.08)
	core_light.light_energy = 3.2
	core_light.omni_range = 4.0
	core_light.position = Vector3(0, 2.3, 0.25)
	root.add_child(core_light); core_light.owner = root

	var col = _make_capsule_col(0.65, 3.8, 1.9)
	root.add_child(col); col.owner = root

	_save(root, "res://scenes/enemy_bioroid.tscn")

# ────────────────────────────────────────────
# 4. 培養槽
# ────────────────────────────────────────────
func _build_bioroid_pod_scene() -> void:
	var root = Node3D.new()
	root.name = "BioroidPod"
	root.set_script(load("res://scripts/bioroid_synthesis_pod.gd"))

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "EtherFluidMesh"
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.75; cyl.bottom_radius = 0.75; cyl.height = 3.2
	mesh_inst.mesh = cyl
	mesh_inst.position = Vector3(0, 1.7, 0)
	if ResourceLoader.exists("res://shaders/cultivation_fluid.gdshader"):
		var mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/cultivation_fluid.gdshader")
		mesh_inst.material_override = mat
	root.add_child(mesh_inst); mesh_inst.owner = root

	var glass = MeshInstance3D.new()
	glass.name = "PodGlass"
	var g_cyl = CylinderMesh.new()
	g_cyl.top_radius = 0.8; g_cyl.bottom_radius = 0.8; g_cyl.height = 3.3
	glass.mesh = g_cyl; glass.position = Vector3(0, 1.7, 0)
	var g_mat = StandardMaterial3D.new()
	g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g_mat.albedo_color = Color(0.7, 0.95, 1.0, 0.2)
	g_mat.roughness = 0.05; g_mat.metallic = 0.2
	glass.material_override = g_mat
	root.add_child(glass); glass.owner = root

	for y_pos in [0.1, 3.35]:
		var rim = MeshInstance3D.new()
		var rim_mesh = CylinderMesh.new()
		rim_mesh.top_radius = 0.95; rim_mesh.bottom_radius = 0.95; rim_mesh.height = 0.22
		rim.mesh = rim_mesh; rim.position = Vector3(0, y_pos, 0)
		var r_mat = StandardMaterial3D.new()
		r_mat.albedo_color = Color(0.18, 0.22, 0.28); r_mat.metallic = 0.85; r_mat.roughness = 0.2
		rim.material_override = r_mat
		root.add_child(rim); rim.owner = root

	var base = MeshInstance3D.new()
	base.name = "PodBase"
	var box = BoxMesh.new(); box.size = Vector3(2.2, 0.25, 2.2)
	base.mesh = box; base.position = Vector3(0, 0.125, 0)
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.12, 0.15, 0.2); b_mat.metallic = 0.7
	base.material_override = b_mat
	root.add_child(base); base.owner = root

	var light = OmniLight3D.new()
	light.name = "PodLight"
	light.light_color = Color(0.0, 0.96, 0.90)
	light.light_energy = 3.5; light.omni_range = 8.0
	light.position = Vector3(0, 1.8, 0)
	root.add_child(light); light.owner = root

	_save(root, "res://scenes/bioroid_pod.tscn")

# ────────────────────────────────────────────
func _make_world_env(bg_col: Color, amb_col: Color, amb_energy: float) -> WorldEnvironment:
	var we  = WorldEnvironment.new(); we.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode   = Environment.BG_COLOR
	env.background_color  = bg_col
	env.ambient_light_color  = amb_col
	env.ambient_light_energy = amb_energy

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.0

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.04, 0.08, 0.12)

	we.environment = env
	return we

func _make_floor(size: Vector2, tex_path: String, uv_scale: float, y: float = 0.0) -> StaticBody3D:
	var sb = StaticBody3D.new(); sb.name = "Floor"

	var mi = MeshInstance3D.new(); mi.name = "FloorMesh"
	var pm = PlaneMesh.new(); pm.size = size
	mi.mesh = pm; mi.position.y = y

	if ResourceLoader.exists(tex_path):
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = load(tex_path)
		mat.uv1_scale = Vector3(uv_scale, uv_scale, 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.metallic = 0.4
		mat.roughness = 0.45
		mi.material_override = mat

	var cs = CollisionShape3D.new()
	cs.name = "FloorCol"
	cs.shape = BoxShape3D.new()
	(cs.shape as BoxShape3D).size = Vector3(size.x, 0.1, size.y)
	cs.position.y = y - 0.05

	sb.add_child(mi); mi.owner = sb
	sb.add_child(cs); cs.owner = sb
	return sb

# ────────────────────────────────────────────
# 5. 探索シーン
# ────────────────────────────────────────────
func _build_exploration_scene() -> void:
	var root = Node3D.new(); root.name = "ExplorationScene"

	var we = _make_world_env(Color(0.03, 0.05, 0.08), Color(0.06, 0.12, 0.16), 0.75)
	root.add_child(we); we.owner = root

	var dl = DirectionalLight3D.new(); dl.name = "DirLight"
	dl.shadow_enabled = true; dl.light_energy = 1.4; dl.light_color = Color(0.82, 0.94, 1.0)
	dl.rotation_degrees = Vector3(-42, 30, 0)
	root.add_child(dl); dl.owner = root

	var floor_sb = _make_floor(Vector2(20, 20), "res://assets/floor_grid.png", 6.0)
	root.add_child(floor_sb); floor_sb.owner = root
	for c in floor_sb.get_children():
		c.owner = root

	var back_wall = MeshInstance3D.new()
	back_wall.name = "BackSecurityWall"
	var bw_mesh = BoxMesh.new(); bw_mesh.size = Vector3(18.0, 6.0, 1.0)
	back_wall.mesh = bw_mesh; back_wall.position = Vector3(0, 3.0, -6.5)
	var bw_mat = StandardMaterial3D.new()
	bw_mat.albedo_color = Color(0.08, 0.11, 0.15); bw_mat.metallic = 0.85; bw_mat.roughness = 0.3
	back_wall.material_override = bw_mat
	root.add_child(back_wall); back_wall.owner = root

	var player_inst: Node3D = null
	if ResourceLoader.exists("res://scenes/investigator_player.tscn"):
		player_inst = (load("res://scenes/investigator_player.tscn") as PackedScene).instantiate()
		player_inst.position = Vector3(0, 0, 0)
		root.add_child(player_inst); player_inst.owner = root

	if ResourceLoader.exists("res://scenes/enemy_bioroid.tscn"):
		var enemy = (load("res://scenes/enemy_bioroid.tscn") as PackedScene).instantiate()
		enemy.position = Vector3(-2.2, 0, -1.5)
		root.add_child(enemy); enemy.owner = root

	if ResourceLoader.exists("res://scenes/bioroid_pod.tscn"):
		var pod = (load("res://scenes/bioroid_pod.tscn") as PackedScene).instantiate()
		pod.position = Vector3(2.8, 0, -1.8)
		root.add_child(pod); pod.owner = root

	var cam = Camera3D.new(); cam.name = "MainCamera"
	cam.set_script(load("res://scripts/follow_camera.gd"))
	cam.set("offset", Vector3(0, 2.6, 3.2))
	cam.set("smooth_speed", 5.0)
	if player_inst:
		cam.set("target_path", root.get_path_to(player_inst))
	cam.position = Vector3(0, 2.6, 3.2)
	cam.rotation_degrees = Vector3(-32, 0, 0)
	root.add_child(cam); cam.owner = root

	var cap = Node.new(); cap.name = "AutoCapture"
	cap.set_script(load("res://scripts/auto_capture.gd"))
	cap.set("output_filename", "exploration_demo.png")
	cap.set("delay_seconds", 1.2)
	root.add_child(cap); cap.owner = root

	_save(root, "res://scenes/exploration_scene.tscn")

# ────────────────────────────────────────────
# 6. 隔離実験場・観測アリーナシーン — CONTAINMENT SECTOR-04
# 生体感のある非対称個体 + 5層/4層監査パネル + 施設情報背景
# ────────────────────────────────────────────
func _build_arena_battle_scene() -> void:
	var root = Node3D.new(); root.name = "ArenaBattleScene"

	# 施設環境光（蛍光灯の冷白+赤色警報の混合）
	var we = _make_world_env(Color(0.03, 0.04, 0.06), Color(0.06, 0.09, 0.12), 0.55)
	root.add_child(we); we.owner = root

	# 天井蛍光灯（冷白、やや青みがかった施設光）
	var l_ceil = DirectionalLight3D.new(); l_ceil.name = "CeilingFluorescent"
	l_ceil.shadow_enabled = true; l_ceil.light_energy = 0.9
	l_ceil.light_color = Color(0.82, 0.92, 1.0)
	l_ceil.rotation_degrees = Vector3(-70, 10, 0)
	root.add_child(l_ceil); l_ceil.owner = root

	# 赤色警報灯（右後方・ANOMALY側）
	var l_red = OmniLight3D.new(); l_red.name = "AnomalyAlertLight"
	l_red.light_color = Color(1.0, 0.08, 0.08); l_red.light_energy = 4.0; l_red.omni_range = 9.0
	l_red.position = Vector3(3.0, 3.5, -2.0)
	root.add_child(l_red); l_red.owner = root

	# 観測窓からの青白い透過光
	var l_obs = OmniLight3D.new(); l_obs.name = "ObservationWindowLight"
	l_obs.light_color = Color(0.5, 0.85, 1.0); l_obs.light_energy = 1.8; l_obs.omni_range = 12.0
	l_obs.position = Vector3(-1.5, 2.0, -3.8)
	root.add_child(l_obs); l_obs.owner = root

	# 隔離実験場床（生体汚染・警戒ライン）
	var floor_sb = _make_floor(Vector2(14, 14), "res://assets/arena_floor.png", 5.0)
	root.add_child(floor_sb); floor_sb.owner = root
	for c in floor_sb.get_children():
		c.owner = root

	# ──────── 背景：隔離施設 CONTAINMENT SECTOR-04 ────────
	# 主壁（施設壁パネルテクスチャ）
	var back_wall = MeshInstance3D.new(); back_wall.name = "FacilityBackWall"
	var bw_mesh = BoxMesh.new(); bw_mesh.size = Vector3(15.0, 6.0, 0.5)
	back_wall.mesh = bw_mesh; back_wall.position = Vector3(0, 3.0, -5.0)
	var bw_mat = StandardMaterial3D.new()
	if ResourceLoader.exists("res://assets/facility_wall.png"):
		bw_mat.albedo_texture = load("res://assets/facility_wall.png")
		bw_mat.uv1_scale = Vector3(8.0, 3.0, 1.0)
		bw_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		bw_mat.albedo_color = Color(0.08, 0.10, 0.13)
	bw_mat.metallic = 0.6; bw_mat.roughness = 0.5
	back_wall.material_override = bw_mat
	root.add_child(back_wall); back_wall.owner = root

	# セクター識別看板 (SECTOR-04 // ZONE-Λ)
	var sign_mesh = MeshInstance3D.new(); sign_mesh.name = "SectorSignPlate"
	var sm = BoxMesh.new(); sm.size = Vector3(3.2, 0.7, 0.08)
	sign_mesh.mesh = sm; sign_mesh.position = Vector3(-3.2, 4.6, -4.72)
	var smat = StandardMaterial3D.new()
	smat.albedo_color = Color(0.06, 0.08, 0.1)
	smat.metallic = 0.9
	sign_mesh.material_override = smat
	root.add_child(sign_mesh); sign_mesh.owner = root

	# 観測ガラス窓（背後に観測室の気配）
	var obs_glass = MeshInstance3D.new(); obs_glass.name = "ObservationGlass"
	var og_mesh = BoxMesh.new(); og_mesh.size = Vector3(7.2, 2.2, 0.08)
	obs_glass.mesh = og_mesh; obs_glass.position = Vector3(-1.0, 2.9, -4.72)
	var og_mat = StandardMaterial3D.new()
	og_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	og_mat.albedo_color = Color(0.2, 0.55, 0.8, 0.22)
	og_mat.metallic = 0.6; og_mat.roughness = 0.04
	obs_glass.material_override = og_mat
	root.add_child(obs_glass); obs_glass.owner = root

	# 窓枠フレーム
	for wx in [-4.6, -2.3, 0.0, 2.3]:
		var wf = MeshInstance3D.new()
		var wfm = BoxMesh.new(); wfm.size = Vector3(0.16, 2.4, 0.18)
		wf.mesh = wfm; wf.position = Vector3(wx - 1.0, 2.9, -4.65)
		var wfmat = StandardMaterial3D.new()
		wfmat.albedo_color = Color(0.15, 0.18, 0.23); wfmat.metallic = 0.92; wfmat.roughness = 0.2
		wf.material_override = wfmat
		root.add_child(wf); wf.owner = root

	# 隔離ゲート（LOCKDOWN ACTIVE — 右側）
	var gate = MeshInstance3D.new(); gate.name = "LockdownGate"
	var gm = BoxMesh.new(); gm.size = Vector3(1.6, 5.5, 0.3)
	gate.mesh = gm; gate.position = Vector3(5.4, 2.75, -4.0)
	var gmat = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.10, 0.12, 0.15); gmat.metallic = 0.95; gmat.roughness = 0.25
	gate.material_override = gmat
	root.add_child(gate); gate.owner = root

	# ゲート警告灯（赤）
	var gate_light = MeshInstance3D.new(); gate_light.name = "LockdownLight"
	var glm = BoxMesh.new(); glm.size = Vector3(0.8, 0.22, 0.06)
	gate_light.mesh = glm; gate_light.position = Vector3(5.4, 4.4, -3.8)
	var glmat = StandardMaterial3D.new()
	glmat.albedo_color = Color(0.9, 0.1, 0.1)
	glmat.emission_enabled = true; glmat.emission = Color(0.9, 0.1, 0.1) * 2.0
	gate_light.material_override = glmat
	root.add_child(gate_light); gate_light.owner = root

	# 天井制御アーム（観測機材）
	var ctrl_arm = MeshInstance3D.new(); ctrl_arm.name = "CeilingControlArm"
	var cam_mesh = CylinderMesh.new(); cam_mesh.top_radius = 0.06; cam_mesh.bottom_radius = 0.06; cam_mesh.height = 2.5
	ctrl_arm.mesh = cam_mesh; ctrl_arm.position = Vector3(1.5, 4.2, -3.5)
	ctrl_arm.rotation_degrees = Vector3(45, 20, 0)
	var cam_mat = StandardMaterial3D.new()
	cam_mat.albedo_color = Color(0.2, 0.25, 0.3); cam_mat.metallic = 0.88
	ctrl_arm.material_override = cam_mat
	root.add_child(ctrl_arm); ctrl_arm.owner = root

	var cam_head = MeshInstance3D.new(); cam_head.name = "CameraHead"
	var chm = BoxMesh.new(); chm.size = Vector3(0.25, 0.18, 0.35)
	cam_head.mesh = chm; cam_head.position = Vector3(2.0, 3.1, -2.5)
	cam_head.rotation_degrees = Vector3(15, -20, 0)
	cam_head.material_override = cam_mat
	root.add_child(cam_head); cam_head.owner = root

	# 警報パトランプ×2
	for bpos in [Vector3(4.2, 5.1, -4.7), Vector3(-4.8, 5.1, -4.7)]:
		var beacon = MeshInstance3D.new(); beacon.name = "Beacon"
		var bm = SphereMesh.new(); bm.radius = 0.16; bm.height = 0.32
		beacon.mesh = bm; beacon.position = bpos
		var bmat = StandardMaterial3D.new()
		bmat.albedo_color = Color(0.9, 0.08, 0.08)
		bmat.emission_enabled = true; bmat.emission = Color(0.9, 0.08, 0.08) * 2.2
		beacon.material_override = bmat
		root.add_child(beacon); beacon.owner = root

	# ──────── キャラクター配置（視認性を高めたスケール 55〜62%）────────
	# 味方 BIO-ALD-DEF001（左側・高さ 3.7 units）
	if ResourceLoader.exists("res://scenes/ally_bioroid.tscn"):
		var ally = (load("res://scenes/ally_bioroid.tscn") as PackedScene).instantiate()
		ally.position = Vector3(-2.1, 0, 0.2)
		root.add_child(ally); ally.owner = root

	# 敵性変異体 SUBJECT AF-09（右側・高さ 4.1 units / 1.11倍）
	if ResourceLoader.exists("res://scenes/enemy_bioroid.tscn"):
		var enemy = (load("res://scenes/enemy_bioroid.tscn") as PackedScene).instantiate()
		enemy.position = Vector3(2.0, 0, -0.2)
		root.add_child(enemy); enemy.owner = root

	# ──────── 外部監査官 多層観測HUD（コンパクト・重なりゼロ設計）────────
	var canvas = CanvasLayer.new(); canvas.name = "AuditObservationHUD"
	root.add_child(canvas); canvas.owner = root

	var ui_root = Control.new(); ui_root.name = "UIRoot"
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ui_root); ui_root.owner = root

	# ── ヘッダー：観測カメラフィード識別バー ──
	var header = Panel.new(); header.name = "ObsHeader"
	header.position = Vector2(0, 0); header.size = Vector2(1280, 26)
	var hdr_style = StyleBoxFlat.new()
	hdr_style.bg_color = Color(0.03, 0.05, 0.07, 0.92)
	hdr_style.border_width_bottom = 1
	hdr_style.border_color = Color(0.15, 0.35, 0.45, 0.7)
	header.add_theme_stylebox_override("panel", hdr_style)
	ui_root.add_child(header); header.owner = root

	var hdr_lbl = Label.new()
	hdr_lbl.text = " [OBSERVATION FEED] CONTAINMENT SECTOR-04 // CAM-02  |  AUDIT PROTOCOL: ACTIVE  |  SECURITY LEVEL 4"
	hdr_lbl.position = Vector2(12, 3)
	header.add_child(hdr_lbl); hdr_lbl.owner = root

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.04, 0.06, 0.82)
	panel_style.set_corner_radius_all(2)
	panel_style.border_width_left = 2
	panel_style.border_color = Color(0.0, 0.8, 0.75, 0.6)

	var enemy_panel_style = StyleBoxFlat.new()
	enemy_panel_style.bg_color = Color(0.04, 0.02, 0.03, 0.82)
	enemy_panel_style.set_corner_radius_all(2)
	enemy_panel_style.border_width_right = 2
	enemy_panel_style.border_color = Color(0.9, 0.2, 0.2, 0.6)

	# ── 左パネル：管理バイオロイド（幅260pxでキャラと完全非重複）──
	var lp = Panel.new(); lp.name = "AllyAuditPanel"
	lp.position = Vector2(16, 36); lp.size = Vector2(260, 140)
	lp.add_theme_stylebox_override("panel", panel_style)
	ui_root.add_child(lp); lp.owner = root

	var lp_id = Label.new()
	lp_id.text = "BIO-ALD-001 [ALDEN]"
	lp_id.position = Vector2(10, 6)
	lp.add_child(lp_id); lp_id.owner = root

	var lp_status = Label.new()
	lp_status.text = "STATUS: SUPPRESSED-STABLE"
	lp_status.position = Vector2(10, 26)
	lp.add_child(lp_status); lp_status.owner = root

	var lp_nc = Label.new()
	lp_nc.text = "CONTROL: 85%  |  MUTATION: 14%"
	lp_nc.position = Vector2(10, 48)
	lp.add_child(lp_nc); lp_nc.owner = root

	var lp_nc_bar = ProgressBar.new(); lp_nc_bar.name = "NeuralControlBar"
	lp_nc_bar.position = Vector2(10, 70); lp_nc_bar.size = Vector2(238, 7)
	lp_nc_bar.show_percentage = false
	lp_nc_bar.max_value = 100; lp_nc_bar.value = 85
	lp.add_child(lp_nc_bar); lp_nc_bar.owner = root

	var lp_vi = Label.new()
	lp_vi.text = "CORE: 40%  |  VITAL: 100%"
	lp_vi.position = Vector2(10, 84)
	lp.add_child(lp_vi); lp_vi.owner = root

	var lp_vi_bar = ProgressBar.new(); lp_vi_bar.name = "VitalIntegrityBar"
	lp_vi_bar.position = Vector2(10, 106); lp_vi_bar.size = Vector2(238, 7)
	lp_vi_bar.show_percentage = false
	lp_vi_bar.max_value = 100; lp_vi_bar.value = 100
	lp.add_child(lp_vi_bar); lp_vi_bar.owner = root

	# ── 右パネル：変異被験体（幅260pxで右端にコンパクト配置）──
	var rp = Panel.new(); rp.name = "EnemyAuditPanel"
	rp.position = Vector2(1004, 36); rp.size = Vector2(260, 140)
	rp.add_theme_stylebox_override("panel", enemy_panel_style)
	ui_root.add_child(rp); rp.owner = root

	var rp_id = Label.new()
	rp_id.text = "SUBJECT AF-09 [ANOMALY]"
	rp_id.position = Vector2(10, 6)
	rp.add_child(rp_id); rp_id.owner = root

	var rp_status = Label.new()
	rp_status.text = "STATUS: CRITICAL-UNSTABLE"
	rp_status.position = Vector2(10, 26)
	rp.add_child(rp_status); rp_status.owner = root

	var rp_cont = Label.new()
	rp_cont.text = "BREACH IMMINENT (HOSTILE: 88%)"
	rp_cont.position = Vector2(10, 48)
	rp.add_child(rp_cont); rp_cont.owner = root

	var rp_hi_bar = ProgressBar.new(); rp_hi_bar.name = "HostilityBar"
	rp_hi_bar.position = Vector2(10, 70); rp_hi_bar.size = Vector2(238, 7)
	rp_hi_bar.show_percentage = false
	rp_hi_bar.max_value = 100; rp_hi_bar.value = 88
	rp.add_child(rp_hi_bar); rp_hi_bar.owner = root

	var rp_ms = Label.new()
	rp_ms.text = "SURGE: ACTIVE  |  VITAL: 100%"
	rp_ms.position = Vector2(10, 84)
	rp.add_child(rp_ms); rp_ms.owner = root

	var rp_vi_bar = ProgressBar.new(); rp_vi_bar.name = "EnemyVitalBar"
	rp_vi_bar.position = Vector2(10, 106); rp_vi_bar.size = Vector2(238, 7)
	rp_vi_bar.show_percentage = false
	rp_vi_bar.max_value = 100; rp_vi_bar.value = 100
	rp.add_child(rp_vi_bar); rp_vi_bar.owner = root

	# ── 下部：監査官緊急介入インターフェース（即時判断UI）──
	var cmd = Panel.new(); cmd.name = "AuditorInterventionPanel"
	cmd.position = Vector2(280, 595); cmd.size = Vector2(660, 95)
	var cmd_style = StyleBoxFlat.new()
	cmd_style.bg_color = Color(0.02, 0.04, 0.06, 0.88)
	cmd_style.border_width_top = 2
	cmd_style.border_color = Color(0.85, 0.65, 0.1, 0.65)
	cmd.add_theme_stylebox_override("panel", cmd_style)
	ui_root.add_child(cmd); cmd.owner = root

	var cmd_title = Label.new()
	cmd_title.text = "EMERGENCY AUDIT INTERVENTION:"
	cmd_title.position = Vector2(16, 8)
	cmd.add_child(cmd_title); cmd_title.owner = root

	var cmd_z = Label.new()
	cmd_z.text = "[Z]  NERVOUS CORE SUPPRESSION       (+20% Stability / Cancel Surge)"
	cmd_z.position = Vector2(16, 32)
	cmd.add_child(cmd_z); cmd_z.owner = root

	var cmd_x = Label.new()
	cmd_x.text = "[X]  GENE DISCHARGE OVERRIDE        (40 EP - Critical Suppression Burst)"
	cmd_x.position = Vector2(16, 58)
	cmd.add_child(cmd_x); cmd_x.owner = root

	# ── 右下：セクター情報ログ ──
	var sector_log = Panel.new(); sector_log.name = "SectorInfoLog"
	sector_log.position = Vector2(960, 595); sector_log.size = Vector2(304, 95)
	var log_style = StyleBoxFlat.new()
	log_style.bg_color = Color(0.02, 0.03, 0.05, 0.88)
	sector_log.add_theme_stylebox_override("panel", log_style)
	ui_root.add_child(sector_log); sector_log.owner = root

	var sl_lbl = Label.new()
	sl_lbl.text = "LOC: SECTOR-04 // ZONE-Λ\nCLEARANCE: LEVEL-4\nLOCKDOWN: ENGAGED\nAUDITOR: EXT-0044"
	sl_lbl.position = Vector2(12, 8)
	sector_log.add_child(sl_lbl); sl_lbl.owner = root

	# バトルマネージャー
	var mgr = Node.new(); mgr.name = "ArenaBattleManager"
	mgr.set_script(load("res://scripts/arena_battle_manager.gd"))
	root.add_child(mgr); mgr.owner = root

	# 観測カメラ（キャラのスケールアップに合わせた最適画角）
	var cam = Camera3D.new(); cam.name = "ObservationCamera"
	cam.position = Vector3(0.0, 2.2, 4.6)
	cam.rotation_degrees = Vector3(-12, 0, 0)
	root.add_child(cam); cam.owner = root

	var cap = Node.new(); cap.name = "AutoCapture"
	cap.set_script(load("res://scripts/auto_capture.gd"))
	cap.set("output_filename", "arena_demo.png")
	cap.set("delay_seconds", 1.2)
	root.add_child(cap); cap.owner = root

	_save(root, "res://scenes/arena_battle_scene.tscn")

# ────────────────────────────────────────────
# 7. Gene Mixer ラボシーン
# ────────────────────────────────────────────
func _build_gene_mixer_scene() -> void:
	var root = Node3D.new(); root.name = "GeneMixerLabScene"

	var we = _make_world_env(Color(0.02, 0.04, 0.07), Color(0.05, 0.10, 0.15), 0.8)
	root.add_child(we); we.owner = root

	var dl = DirectionalLight3D.new(); dl.name = "LabLight"
	dl.shadow_enabled = true; dl.light_energy = 1.3; dl.light_color = Color(0.85, 0.95, 1.0)
	dl.rotation_degrees = Vector3(-45, 25, 0)
	root.add_child(dl); dl.owner = root

	var floor_sb = _make_floor(Vector2(20, 20), "res://assets/floor_grid.png", 6.0)
	root.add_child(floor_sb); floor_sb.owner = root
	for c in floor_sb.get_children():
		c.owner = root

	var pod_inst: Node3D = null
	if ResourceLoader.exists("res://scenes/bioroid_pod.tscn"):
		pod_inst = (load("res://scenes/bioroid_pod.tscn") as PackedScene).instantiate()
		pod_inst.position = Vector3(1.6, 0, -1.0)
		root.add_child(pod_inst); pod_inst.owner = root

	if ResourceLoader.exists("res://scenes/investigator_player.tscn"):
		var auditor = (load("res://scenes/investigator_player.tscn") as PackedScene).instantiate()
		auditor.position = Vector3(-1.4, 0, 0.2)
		auditor.rotation_degrees = Vector3(0, 45, 0)
		root.add_child(auditor); auditor.owner = root

	var cam = Camera3D.new(); cam.name = "LabCamera"
	cam.position = Vector3(0.5, 2.4, 4.0)
	cam.rotation_degrees = Vector3(-20, 0, 0)
	root.add_child(cam); cam.owner = root

	var canvas = CanvasLayer.new(); canvas.name = "AuditorCanvas"
	root.add_child(canvas); canvas.owner = root

	var ui = Control.new()
	ui.name = "GeneMixerUI"
	ui.set_script(load("res://scripts/gene_mixer_ui.gd"))
	if pod_inst:
		ui.set("pod_reference", pod_inst)
	canvas.add_child(ui); ui.owner = root

	var cap = Node.new(); cap.name = "AutoCapture"
	cap.set_script(load("res://scripts/auto_capture.gd"))
	cap.set("output_filename", "gene_mixer_demo.png")
	cap.set("delay_seconds", 1.5)
	root.add_child(cap); cap.owner = root

	_save(root, "res://scenes/gene_mixer_lab_scene.tscn")

# ────────────────────────────────────────────
# 8. Sovereign Terminal 統合メイン画面
# ────────────────────────────────────────────
func _build_main_terminal_scene() -> void:
	var root = Control.new()
	root.name = "MainTerminal"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scripts/main_terminal_controller.gd"))

	# 背景
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.05, 1.0)
	root.add_child(bg); bg.owner = root

	# ヘッダー
	var hdr = Panel.new(); hdr.name = "Header"
	hdr.position = Vector2(0, 0); hdr.size = Vector2(1280, 36)
	var hdr_style = StyleBoxFlat.new()
	hdr_style.bg_color = Color(0.04, 0.06, 0.09, 0.95)
	hdr_style.border_width_bottom = 1
	hdr_style.border_color = Color(0.0, 0.8, 0.75, 0.7)
	hdr.add_theme_stylebox_override("panel", hdr_style)
	root.add_child(hdr); hdr.owner = root

	var hdr_lbl = Label.new(); hdr_lbl.name = "StatusLabel"
	hdr_lbl.text = "SOVEREIGN AUDITOR OS v1.0.4 | RUN-0001 | ACTIVE CONSOLE"
	hdr_lbl.position = Vector2(16, 7)
	hdr.add_child(hdr_lbl); hdr_lbl.owner = root

	# Views コンテナ
	var views = Control.new(); views.name = "Views"
	views.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(views); views.owner = root

	# ── 1. TerminalView ──
	var term_view = Control.new(); term_view.name = "TerminalView"
	term_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	views.add_child(term_view); term_view.owner = root

	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.03, 0.05, 0.08, 0.85)
	p_style.border_width_left = 2; p_style.border_color = Color(0.0, 0.8, 0.75, 0.6)
	p_style.set_corner_radius_all(3)

	# 左パネル: システムステータス
	var p_sys = Panel.new(); p_sys.name = "SystemStatusPanel"
	p_sys.position = Vector2(24, 60); p_sys.size = Vector2(360, 580)
	p_sys.add_theme_stylebox_override("panel", p_style)
	term_view.add_child(p_sys); p_sys.owner = root

	var lbl_sys_t = Label.new(); lbl_sys_t.text = "[A] SYSTEM STATUS & PROTOCOLS"
	lbl_sys_t.position = Vector2(16, 16); p_sys.add_child(lbl_sys_t); lbl_sys_t.owner = root

	var lbl_sys_c = Label.new()
	lbl_sys_c.text = "• SECTOR: ZONE-Λ (CONTAINMENT)\n• MUTATION DRIFT: 0.04%\n• NEURAL THRESHOLD: 85%\n• SECURITY LEVEL: AUDITOR PRIORITY 4\n• AUTHORITY: SOVEREIGN LEDGER (DECISIVE)\n• AI STATUS: generation_is_not_authority"
	lbl_sys_c.position = Vector2(16, 50); p_sys.add_child(lbl_sys_c); lbl_sys_c.owner = root

	# 中央パネル: Active Run Context
	var p_run = Panel.new(); p_run.name = "RunContextPanel"
	p_run.position = Vector2(408, 60); p_run.size = Vector2(464, 580)
	p_run.add_theme_stylebox_override("panel", p_style)
	term_view.add_child(p_run); p_run.owner = root

	var lbl_run_t = Label.new(); lbl_run_t.text = "[B] ACTIVE RUN OPERATION"
	lbl_run_t.position = Vector2(16, 16); p_run.add_child(lbl_run_t); lbl_run_t.owner = root

	var lbl_run_c = Label.new(); lbl_run_c.name = "RunContextLabel"
	lbl_run_c.text = "ACTIVE RUN: RUN-0001\nSPECIMEN: AWAITING SYNTHESIS\nFRAGMENTS: 0\n\nTARGET: SUBJECT AF-09 [LAMBDA ANOMALY]\nHOSTILITY: 88% (SURGE DETECTED)\nCONTAINMENT INTEGRITY: NORMAL"
	lbl_run_c.position = Vector2(16, 50); p_run.add_child(lbl_run_c); lbl_run_c.owner = root

	# 右パネル: Sovereign Ledger 概要
	var p_led = Panel.new(); p_led.name = "LedgerSummaryPanel"
	p_led.position = Vector2(896, 60); p_led.size = Vector2(360, 580)
	p_led.add_theme_stylebox_override("panel", p_style)
	term_view.add_child(p_led); p_led.owner = root

	var lbl_led_t = Label.new(); lbl_led_t.text = "[C] SOVEREIGN AUDIT LEDGER"
	lbl_led_t.position = Vector2(16, 16); p_led.add_child(lbl_led_t); lbl_led_t.owner = root

	var lbl_led_c = Label.new(); lbl_led_c.name = "LedgerSummaryLabel"
	lbl_led_c.text = "COMMITTED LEDGER ENTRIES: 0\n\nINTERVENTIONS CONTRACT:\n• [Z] NERVOUS CORE STABILIZATION\n• [X] GENE DISCHARGE SUPPRESSION\n\nAll outcomes recorded deterministically."
	lbl_led_c.position = Vector2(16, 50); p_led.add_child(lbl_led_c); lbl_led_c.owner = root

	# ── 2. ExpeditionView ──
	var exp_view = Control.new(); exp_view.name = "ExpeditionView"
	exp_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	exp_view.visible = false
	views.add_child(exp_view); exp_view.owner = root

	var exp_p = Panel.new(); exp_p.position = Vector2(200, 100); exp_p.size = Vector2(880, 480)
	exp_p.add_theme_stylebox_override("panel", p_style)
	exp_view.add_child(exp_p); exp_p.owner = root

	var exp_t = Label.new(); exp_t.text = "ZONE-Λ EXPEDITION SECTOR OBSERVER"
	exp_t.position = Vector2(24, 20); exp_p.add_child(exp_t); exp_t.owner = root

	var exp_inst = Label.new(); exp_inst.name = "ExpeditionInfoLabel"
	exp_inst.text = "Contaminated sectors detected.\n\n• [Z / SPACE]: EXPLORE NEXT SECTOR & HARVEST GENE FRAGMENTS\n• [TAB]: RETURN TO LAB WITH HARVESTED FRAGMENTS"
	exp_inst.position = Vector2(24, 70); exp_p.add_child(exp_inst); exp_inst.owner = root

	# ── 3. GeneMixerView ──
	var mix_view = Control.new(); mix_view.name = "GeneMixerView"
	mix_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	mix_view.visible = false
	views.add_child(mix_view); mix_view.owner = root

	var mix_p = Panel.new(); mix_p.position = Vector2(200, 100); mix_p.size = Vector2(880, 480)
	mix_p.add_theme_stylebox_override("panel", p_style)
	mix_view.add_child(mix_p); mix_p.owner = root

	var mix_t = Label.new(); mix_t.text = "BIOROID SYNTHESIS & POD CHAMBER"
	mix_t.position = Vector2(24, 20); mix_p.add_child(mix_t); mix_p.owner = root

	var mix_inst = Label.new()
	mix_inst.text = "4-Layer Parametric Synthesis Ready.\n\n• [SPACE]: SYNTHESIZE SPECIMEN & DEPLOY TO CONTAINMENT ARENA\n• [TAB]: PROCEED WITH ACTIVE SPECIMEN"
	mix_inst.position = Vector2(24, 70); mix_p.add_child(mix_inst); mix_inst.owner = root

	# ── 4. ArenaView ──
	var arena_v = Control.new(); arena_v.name = "ArenaView"
	arena_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena_v.visible = false
	views.add_child(arena_v); arena_v.owner = root

	var arena_mgr = Node.new(); arena_mgr.name = "ArenaBattleManager"
	arena_mgr.set_script(load("res://scripts/arena_battle_manager.gd"))
	arena_v.add_child(arena_mgr); arena_mgr.owner = root

	# ── 5. LedgerView ──
	var led_view = Control.new(); led_view.name = "LedgerView"
	led_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	led_view.visible = false
	views.add_child(led_view); led_view.owner = root

	var led_p = Panel.new(); led_p.position = Vector2(200, 100); led_p.size = Vector2(880, 480)
	led_p.add_theme_stylebox_override("panel", p_style)
	led_view.add_child(led_p); led_p.owner = root

	var led_t = Label.new(); led_t.text = "SOVEREIGN AUDIT REPORT & DEPLOYMENT COMMIT"
	led_t.position = Vector2(24, 20); led_p.add_child(led_t); led_t.owner = root

	var led_info = Label.new()
	led_info.text = "Combat outcome verified and committed to immutable Sovereign Audit Ledger.\n\n• [SPACE]: ACKNOWLEDGE REPORT & RETURN TO SOVEREIGN TERMINAL"
	led_info.position = Vector2(24, 70); led_p.add_child(led_info); led_info.owner = root

	# フッター
	var ftr = Panel.new(); ftr.name = "Footer"
	ftr.position = Vector2(0, 680); ftr.size = Vector2(1280, 40)
	var ftr_style = StyleBoxFlat.new()
	ftr_style.bg_color = Color(0.04, 0.06, 0.09, 0.95)
	ftr_style.border_width_top = 1
	ftr_style.border_color = Color(0.0, 0.8, 0.75, 0.7)
	ftr.add_theme_stylebox_override("panel", ftr_style)
	root.add_child(ftr); ftr.owner = root

	var ftr_lbl = Label.new(); ftr_lbl.name = "PromptLabel"
	ftr_lbl.text = "> NEXT ACTION: [SPACE] INITIATE ZONE-Λ EXPEDITION"
	ftr_lbl.position = Vector2(16, 10)
	ftr.add_child(ftr_lbl); ftr_lbl.owner = root

	_save(root, "res://scenes/main_terminal.tscn")
