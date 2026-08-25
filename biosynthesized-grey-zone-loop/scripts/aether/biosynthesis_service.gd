class_name BiosynthesisService
extends RefCounted


func generate(
	materials: Array[MaterialDefinition],
	components: Array[ComponentDefinition],
	seed: int,
	entity_id: String,
	batch_id: String,
	origin_ids: Array[String] = []
) -> ManufacturableEntity:
	var result := ManufacturableEntity.new()
	result.generation_seed = seed

	var quality_total := 0
	var quality_count := 0
	for definition in materials:
		result.materials.append(definition.material_id)
		_append_unique(result.traits, definition.traits)
		_append_unique(result.defects, definition.defects)
		quality_total += definition.quality_q
		quality_count += 1

	for definition in components:
		result.components.append(definition.component_id)
		_append_unique(result.traits, definition.traits)
		_append_unique(result.defects, definition.defects)
		quality_total += definition.quality_q
		quality_count += 1

	result.quality_q = quality_total / quality_count if quality_count > 0 else 0
	result.manufacturing_record = ManufacturingRecord.new()
	result.manufacturing_record.configure(entity_id, batch_id, origin_ids)
	return result


func _append_unique(target: Array[String], source: Array[String]) -> void:
	for value in source:
		if not target.has(value):
			target.append(value)
