extends SceneTree

const MATERIAL_PATH := "res://data/aether/materials/aether_gel.tres"
const COMPONENT_PATH := "res://data/aether/components/neural_lattice.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	print("[BIO-DATA-v0]")
	var material := load(MATERIAL_PATH) as MaterialDefinition
	var component := load(COMPONENT_PATH) as ComponentDefinition
	_check(material != null and component != null, "fixtures load")
	if material == null or component == null:
		_finish()
		return

	var materials: Array[MaterialDefinition] = [material]
	var components: Array[ComponentDefinition] = [component]
	var origins: Array[String] = ["ORIGIN-A", "ORIGIN-B"]
	var service := BiosynthesisService.new()
	var before := _input_snapshot(materials, components)
	var root_children_before := root.get_child_count()
	var registry_before := _registry_snapshot()

	var first := service.generate(materials, components, 424242, "ENTITY-001", "BATCH-009", origins)
	var second := service.generate(materials, components, 424242, "ENTITY-OTHER", "BATCH-OTHER", ["OTHER"])

	_gate_01(first, second)
	_gate_02(before, _input_snapshot(materials, components), materials, components, material, component)
	_gate_03(first)
	_gate_04(service, root_children_before, registry_before)
	_gate_05(first, origins)
	_finish()


func _gate_01(first: ManufacturableEntity, second: ManufacturableEntity) -> void:
	var passed := first.canonical_generation_result() == second.canonical_generation_result()
	passed = passed and first.traits == ["conductive", "adaptive", "responsive"]
	passed = passed and first.defects == ["signal_noise"]
	_check(passed, "BIO-DATA-01 Determinism (canonical sequences compared without sort)")


func _gate_02(
	before: Dictionary,
	after: Dictionary,
	materials: Array[MaterialDefinition],
	components: Array[ComponentDefinition],
	material: MaterialDefinition,
	component: ComponentDefinition
) -> void:
	var passed := before == after
	passed = passed and materials.size() == 1 and components.size() == 1
	passed = passed and materials[0] == material and components[0] == component
	_check(passed, "BIO-DATA-02 Input Immutability (fields/size/order/references)")


func _gate_03(entity: ManufacturableEntity) -> void:
	var passed := entity.materials != null and entity.components != null
	passed = passed and entity.traits != null and entity.defects != null
	passed = passed and entity.manufacturing_record != null
	passed = passed and entity.generation_seed == 424242
	passed = passed and entity.quality_q >= 60 and entity.quality_q <= 80
	_check(passed, "BIO-DATA-03 Schema Completeness")


func _gate_04(service: BiosynthesisService, root_children_before: int, registry_before: Dictionary) -> void:
	var passed := service is RefCounted
	passed = passed and root.get_child_count() == root_children_before
	passed = passed and _registry_snapshot() == registry_before
	_check(passed, "BIO-DATA-04 Side-Effect Isolation (SceneTree/Autoload unchanged)")


func _gate_05(entity: ManufacturableEntity, origins: Array[String]) -> void:
	var record := entity.manufacturing_record
	var passed := record.entity_id == "ENTITY-001"
	passed = passed and record.batch_id == "BATCH-009"
	passed = passed and record.origin_ids == origins and not is_same(record.origin_ids, origins)
	passed = passed and not entity.canonical_generation_result().has("entity_id")
	passed = passed and not entity.canonical_generation_result().has("batch_id")
	passed = passed and not entity.canonical_generation_result().has("created_at")
	_check(passed, "BIO-DATA-05 Identity Separation")


func _input_snapshot(materials: Array[MaterialDefinition], components: Array[ComponentDefinition]) -> Dictionary:
	var material_fields: Array[Dictionary] = []
	var component_fields: Array[Dictionary] = []
	var material_refs: Array[int] = []
	var component_refs: Array[int] = []
	for definition in materials:
		material_fields.append(definition.canonical_fields())
		material_refs.append(definition.get_instance_id())
	for definition in components:
		component_fields.append(definition.canonical_fields())
		component_refs.append(definition.get_instance_id())
	return {
		"material_fields": material_fields,
		"component_fields": component_fields,
		"material_refs": material_refs,
		"component_refs": component_refs,
	}


func _registry_snapshot() -> Dictionary:
	var registry := root.get_node_or_null("BioroidRegistry")
	if registry == null:
		return {}
	var snapshot := {}
	for property in registry.get_property_list():
		if property["usage"] & PROPERTY_USAGE_STORAGE:
			snapshot[property["name"]] = registry.get(property["name"])
	return snapshot.duplicate(true)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS | %s" % label)
	else:
		_failures.append(label)
		push_error("FAIL | %s" % label)


func _finish() -> void:
	print("BIO-DATA-v0 RESULT | %d/5 PASS | %d FAIL" % [5 - _failures.size(), _failures.size()])
	quit(0 if _failures.is_empty() else 1)
