extends Node3D

# =============================================================================
# 第4設備「Gene Mixer 培養槽 (Cultivation Chamber #04)」
# 三国パラメトリック演出・シェーダー制御・監査通知
# =============================================================================

signal synthesis_started(record: Dictionary)
signal synthesis_progress_updated(progress: float)
signal synthesis_completed(record: Dictionary)

@export var pod_name: String = "Gene Mixer Pod #04"
@export var ether_fluid_mesh: MeshInstance3D
@export var pod_light: OmniLight3D
@export var bubble_particles: GPUParticles3D

enum PodStatus { IDLE, IN_SYNTHESIS, PURGING, ANOMALY_ALERT }
var status: PodStatus = PodStatus.IDLE

var current_progress: float = 0.0
var synthesis_duration: float = 4.0
var current_synthesis_record: Dictionary = {}

func _ready() -> void:
	if not ether_fluid_mesh:
		ether_fluid_mesh = get_node_or_null("EtherFluidMesh") as MeshInstance3D
	if not pod_light:
		pod_light = get_node_or_null("PodLight") as OmniLight3D

func _process(delta: float) -> void:
	if status == PodStatus.IN_SYNTHESIS:
		current_progress += delta / synthesis_duration
		synthesis_progress_updated.emit(clampf(current_progress, 0.0, 1.0))
		
		# 進行度に応じたパルスとエネルギーの激化演出
		if ether_fluid_mesh and ether_fluid_mesh.material_override:
			var mat = ether_fluid_mesh.material_override as ShaderMaterial
			if mat:
				var base_pulse = current_synthesis_record.get("shader_params", {}).get("pulse_speed", 3.5)
				var base_distort = 0.2 + current_progress * 0.4
				mat.set_shader_parameter("pulse_speed", base_pulse + current_progress * 8.0)
				mat.set_shader_parameter("distortion_strength", base_distort)
				mat.set_shader_parameter("emission_energy", 1.2 + current_progress * 2.0)

		# ライトの明滅
		if pod_light:
			var pulse = sin(Time.get_ticks_msec() * 0.015 * (1.0 + current_progress * 2.0)) * 0.8
			pod_light.light_energy = 2.5 + pulse

		if current_progress >= 1.0:
			_complete_synthesis()

func apply_synthesis_parameters(record: Dictionary) -> void:
	current_synthesis_record = record
	var sparams: Dictionary = record.get("shader_params", {})
	
	# シェーダーパラメータの即時適用
	if ether_fluid_mesh and ether_fluid_mesh.material_override:
		var mat = ether_fluid_mesh.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("liquid_color", sparams.get("liquid_color", Color(0.05, 0.45, 0.55, 0.7)))
			mat.set_shader_parameter("glow_color", sparams.get("glow_color", Color(0.0, 0.95, 0.9, 1.0)))
			mat.set_shader_parameter("metallic_val", sparams.get("metallic_val", 0.6))
			mat.set_shader_parameter("roughness_val", sparams.get("roughness_val", 0.15))
			mat.set_shader_parameter("bubble_speed", sparams.get("bubble_speed", 1.8))
			mat.set_shader_parameter("pulse_speed", sparams.get("pulse_speed", 3.5))

	# ライトカラーの適用
	if pod_light:
		pod_light.light_color = sparams.get("glow_color", Color(0.1, 0.95, 0.85))

func start_synthesis(record: Dictionary) -> void:
	if status != PodStatus.IDLE:
		push_warning("[%s] Pod is busy!" % pod_name)
		return

	apply_synthesis_parameters(record)
	status = PodStatus.IN_SYNTHESIS
	current_progress = 0.0

	if bubble_particles:
		bubble_particles.emitting = true

	synthesis_started.emit(record)
	print("[%s] Commencing 4-Layer Synthesis for ID: %s" % [pod_name, record.get("individual_id", "UNKNOWN")])

func _complete_synthesis() -> void:
	var is_anomaly = current_synthesis_record.get("admission_gate", {}).get("is_lambda_anomaly", false)
	status = PodStatus.ANOMALY_ALERT if is_anomaly else PodStatus.PURGING

	if bubble_particles:
		bubble_particles.emitting = false

	synthesis_completed.emit(current_synthesis_record)
	print("[%s] Synthesis Finished! Admission Status: %s" % [
		pod_name, current_synthesis_record.get("admission_gate", {}).get("status", "UNKNOWN")
	])

	# 冷却・洗浄シークエンス後にIDLE復帰
	get_tree().create_timer(3.0).timeout.connect(func():
		status = PodStatus.IDLE
		current_progress = 0.0
	)
