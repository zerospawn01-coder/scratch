class_name MaterialDefinition
extends Resource

@export var material_id: String = ""
@export var traits: Array[String] = []
@export var quality_q: int = 0
@export var defects: Array[String] = []


func canonical_fields() -> Dictionary:
	return {
		"material_id": material_id,
		"traits": traits.duplicate(),
		"quality_q": quality_q,
		"defects": defects.duplicate(),
	}
