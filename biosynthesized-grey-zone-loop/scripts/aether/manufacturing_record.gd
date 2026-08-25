class_name ManufacturingRecord
extends Resource

@export var entity_id: String = ""
@export var batch_id: String = ""
@export var origin_ids: Array[String] = []


func configure(p_entity_id: String, p_batch_id: String, p_origin_ids: Array[String]) -> void:
	entity_id = p_entity_id
	batch_id = p_batch_id
	origin_ids = p_origin_ids.duplicate()
