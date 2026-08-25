class_name GeneMixerController
extends RefCounted

# =============================================================================
# Gene Mixer (遺伝子合成) 4層パラメトリック合成コントローラー
# 思想: generation_is_not_authority（決定論的・再現性・監査台帳の完全性）
# =============================================================================

# 三国の定義カラー
const COLOR_ALDEN_CYAN: Color    = Color(0.0, 0.96, 0.90, 1.0) # #00F5E6
const COLOR_TSELLINA_AMBER: Color = Color(1.0, 0.60, 0.0, 1.0)  # #FF9900
const COLOR_ELPHADIA_CRIMSON: Color = Color(1.0, 0.125, 0.25, 1.0) # #FF2040

const COLOR_ALDEN_LIQUID: Color    = Color(0.05, 0.35, 0.50, 0.70)
const COLOR_TSELLINA_LIQUID: Color = Color(0.40, 0.25, 0.05, 0.75)
const COLOR_ELPHADIA_LIQUID: Color = Color(0.35, 0.05, 0.15, 0.80)

# BIO-DATA-v0 boundary. Identity values are supplied by the caller and are not
# inferred from synthesis data or runtime state.
static func generate_entity(
	materials: Array[MaterialDefinition],
	components: Array[ComponentDefinition],
	seed: int,
	entity_id: String,
	batch_id: String,
	origin_ids: Array[String] = []
) -> ManufacturableEntity:
	return BiosynthesisService.new().generate(
		materials, components, seed, entity_id, batch_id, origin_ids
	)

# 4層パラメトリック合成関数
static func synthesize(dna_ratios: Dictionary, world_seed: int = 1337) -> Dictionary:
	# 1. 比率の正規化 (Normalize: alden + tsellina + elphadia = 1.0)
	var raw_a: float = maxf(0.0, float(dna_ratios.get("alden", 0.0)))
	var raw_t: float = maxf(0.0, float(dna_ratios.get("tsellina", 0.0)))
	var raw_e: float = maxf(0.0, float(dna_ratios.get("elphadia", 0.0)))
	var total: float = raw_a + raw_t + raw_e

	if total <= 0.001:
		raw_a = 1.0; raw_t = 0.0; raw_e = 0.0; total = 1.0

	var r_alden: float    = raw_a / total
	var r_tsellina: float = raw_t / total
	var r_elphadia: float = raw_e / total

	# 【第1層】ベースシルエット（最大比率国家＆副次国家）
	var nations = [
		{"id": "alden", "ratio": r_alden},
		{"id": "tsellina", "ratio": r_tsellina},
		{"id": "elphadia", "ratio": r_elphadia}
	]
	nations.sort_custom(func(x, y): return x["ratio"] > y["ratio"])
	var dominant_nation: String = nations[0]["id"]
	var secondary_nation: String = nations[1]["id"] if nations[1]["ratio"] > 0.05 else "none"

	# 【第2層】シェーダー＆マテリアル合成
	# 発光色 = (Alden * Cyan) + (Tsellina * Amber) + (Elphadia * Crimson)
	var blend_glow: Color = (
		COLOR_ALDEN_CYAN * r_alden +
		COLOR_TSELLINA_AMBER * r_tsellina +
		COLOR_ELPHADIA_CRIMSON * r_elphadia
	)
	var blend_liquid: Color = (
		COLOR_ALDEN_LIQUID * r_alden +
		COLOR_TSELLINA_LIQUID * r_tsellina +
		COLOR_ELPHADIA_LIQUID * r_elphadia
	)

	# 質感パラメータ (Metallic / Roughness)
	# オルデン優勢: metallic=0.8, roughness=0.1
	# チェリーナ優勢: metallic=0.9, roughness=0.4
	# エルファディア優勢: metallic=0.2, roughness=0.05
	var metallic_val: float = (0.80 * r_alden) + (0.90 * r_tsellina) + (0.20 * r_elphadia)
	var roughness_val: float = (0.10 * r_alden) + (0.40 * r_tsellina) + (0.05 * r_elphadia)
	var bubble_speed: float = (1.5 * r_alden) + (3.2 * r_tsellina) + (2.0 * r_elphadia)
	var pulse_speed: float  = (4.0 * r_alden) + (2.0 * r_tsellina) + (6.5 * r_elphadia)

	# 【第3層】エネルギー・パーティクルエフェクト
	var particle_type: String = "data_grid_cyan"
	if dominant_nation == "tsellina":
		particle_type = "spark_amber_heavy"
	elif dominant_nation == "elphadia":
		particle_type = "bio_spores_crimson"

	# 【第4層】ステータス計算 & 監査官検証ゲート（Admission Gate）
	# 基礎ステータス (HP, 耐久Frame, 解析Analysis, 変異親和Mutation)
	var max_hp: int = int(140 + (120 * r_tsellina) + (60 * r_elphadia))
	var durability: float = (50.0 * r_tsellina) + (20.0 * r_alden)
	var analysis_efficiency: float = (100.0 * r_alden) + (15.0 * r_tsellina)
	var mutation_rate: float = clampf(
		(r_elphadia * 0.95) + (absf(r_alden - r_tsellina) * 0.15),
		0.0, 1.0
	)
	var is_lambda_anomaly: bool = (mutation_rate >= 0.85)

	# 決定論的個体ハッシュの生成 (SHA-256)
	var seed_hasher = HashingContext.new()
	seed_hasher.start(HashingContext.HASH_SHA256)
	var raw_str = "SEED:%d:A:%.4f:T:%.4f:E:%.4f" % [world_seed, r_alden, r_tsellina, r_elphadia]
	seed_hasher.update(raw_str.to_utf8_buffer())
	var digest = seed_hasher.finish()
	var individual_hash: String = digest.hex_encode().substr(0, 16).to_upper()
	var individual_id: String = "BIO-%s-%s" % [dominant_nation.substr(0, 3).to_upper(), individual_hash.substr(0, 6)]

	# 監査官台帳レコード (Ledger Entry)
	var ledger_record: Dictionary = {
		"individual_id": individual_id,
		"individual_hash": individual_hash,
		"dominant_nation": dominant_nation,
		"secondary_nation": secondary_nation,
		"dna_ratios": {
			"alden": r_alden,
			"tsellina": r_tsellina,
			"elphadia": r_elphadia
		},
		"stats": {
			"max_hp": max_hp,
			"durability": durability,
			"analysis_efficiency": analysis_efficiency,
			"mutation_rate": mutation_rate
		},
		"admission_gate": {
			"status": "ANOMALY_RESTRICTED" if is_lambda_anomaly else "ADMITTED_CLEAR",
			"is_lambda_anomaly": is_lambda_anomaly,
			"protocol": "SOVEREIGN_LOCKDOWN_AUDIT_v1"
		},
		"shader_params": {
			"liquid_color": blend_liquid,
			"glow_color": blend_glow,
			"metallic_val": metallic_val,
			"roughness_val": roughness_val,
			"bubble_speed": bubble_speed,
			"pulse_speed": pulse_speed
		},
		"particle_type": particle_type
	}

	return ledger_record
