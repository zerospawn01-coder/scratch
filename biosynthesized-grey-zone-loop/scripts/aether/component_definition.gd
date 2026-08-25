class_name ComponentDefinition
extends Resource

@export var component_id: String = ""
@export var traits: Array[String] = []
@export var quality_q: int = 0
@export var defects: Array[String] = []


func canonical_fields() -> Dictionary:
	return {
		"component_id": component_id,
		"traits": traits.duplicate(),
		"quality_q": quality_q,
		"defects": defects.duplicate(),
	}
