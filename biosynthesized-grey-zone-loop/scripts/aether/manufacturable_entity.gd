class_name ManufacturableEntity
extends Resource

@export var materials: Array[String] = []
@export var components: Array[String] = []
@export var traits: Array[String] = []
@export var quality_q: int = 0
@export var defects: Array[String] = []
@export var manufacturing_record: ManufacturingRecord
@export var generation_seed: int = 0


func canonical_generation_result() -> Dictionary:
	return {
		"material_ids": materials.duplicate(),
		"component_ids": components.duplicate(),
		"traits": traits.duplicate(),
		"quality_q": quality_q,
		"defects": defects.duplicate(),
		"generation_seed": generation_seed,
	}
