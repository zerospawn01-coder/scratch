extends SceneTree

const EXPECTED_DIAGNOSTIC := "BIOSYNTHESIS CANDIDATE\n\nENTITY       CANDIDATE-RUN-0001\nBATCH        RUN-0001-BIO\nMATERIAL     MAT-AETHER-GEL\nCOMPONENT    CMP-NEURAL-LATTICE\nTRAITS       conductive / adaptive / responsive\nQUALITY      70 / 100\nDEFECTS      signal_noise\nSEED         424242\n\nSTATUS       UNREGISTERED / DIAGNOSTIC ONLY"

var _failures: Array[String] = []


func _initialize() -> void:
	print("[BIO-LOOP-v0]")
	var packed_scene := load("res://scenes/main_terminal.tscn") as PackedScene
	var controller := packed_scene.instantiate() as MainTerminalController
	root.add_child(controller)
	controller.transition_to_state(MainTerminalController.State.STATE_GENE_MIXER, false)

	var registry := controller.bioroid_registry
	var material_ref := controller.selected_bio_material
	var component_ref := controller.selected_bio_component
	var registry_before := _registry_snapshot(registry)
	var payload_before := controller.active_specimen_payload.duplicate(true)
	var filesystem_before := _filesystem_snapshot()
	var generation_before := controller.biosynthesis_generation_count

	_gate_01(controller, material_ref, component_ref)
	var first := controller.generate_biosynthesis_candidate(
		424242, "CANDIDATE-RUN-0001", "RUN-0001-BIO", ["ORIGIN-A"]
	)
	_gate_02(controller, first, generation_before)
	var first_presentation := controller.lbl_mixer_info.text
	_gate_03(controller, first, first_presentation)
	_gate_04(controller, registry, registry_before, payload_before, filesystem_before)

	var second := controller.generate_biosynthesis_candidate(
		424242, "CANDIDATE-RUN-0001", "RUN-0001-BIO", ["ORIGIN-A"]
	)
	var second_presentation := controller.lbl_mixer_info.text
	_gate_05(first, second, first_presentation, second_presentation)
	_finish()


func _gate_01(controller: MainTerminalController, material: MaterialDefinition, component: ComponentDefinition) -> void:
	var passed := material != null and component != null
	passed = passed and material.material_id == "MAT-AETHER-GEL"
	passed = passed and component.component_id == "CMP-NEURAL-LATTICE"
	passed = passed and controller.selected_bio_material == material
	passed = passed and controller.selected_bio_component == component
	_check(passed, "BIO-LOOP-01 Definition Binding")


func _gate_02(controller: MainTerminalController, entity: ManufacturableEntity, generation_before: int) -> void:
	var record := entity.manufacturing_record if entity != null else null
	var passed := controller.current_state == MainTerminalController.State.STATE_GENE_MIXER
	passed = passed and entity != null and controller.active_biosynthesis_entity == entity
	passed = passed and controller.biosynthesis_generation_count == generation_before + 1
	passed = passed and entity.generation_seed == 424242
	passed = passed and record != null and record.entity_id == "CANDIDATE-RUN-0001"
	passed = passed and record.batch_id == "RUN-0001-BIO" and record.origin_ids == ["ORIGIN-A"]
	_check(passed, "BIO-LOOP-02 Single Generation Boundary")


func _gate_03(controller: MainTerminalController, entity: ManufacturableEntity, presentation: String) -> void:
	var passed := presentation == EXPECTED_DIAGNOSTIC
	passed = passed and presentation == controller.format_biosynthesis_diagnostic(entity)
	_check(passed, "BIO-LOOP-03 Diagnostic Fidelity")


func _gate_04(
	controller: MainTerminalController,
	registry: Node,
	registry_before: Dictionary,
	payload_before: Dictionary,
	filesystem_before: Array[String]
) -> void:
	var passed := controller.current_state == MainTerminalController.State.STATE_GENE_MIXER
	passed = passed and _registry_snapshot(registry) == registry_before
	passed = passed and controller.active_specimen_payload == payload_before
	passed = passed and _filesystem_snapshot() == filesystem_before
	_check(passed, "BIO-LOOP-04 No Implicit Promotion")


func _gate_05(
	first: ManufacturableEntity,
	second: ManufacturableEntity,
	first_presentation: String,
	second_presentation: String
) -> void:
	var passed := first.canonical_generation_result() == second.canonical_generation_result()
	passed = passed and first_presentation == second_presentation
	_check(passed, "BIO-LOOP-05 Repeatability / Regression")


func _registry_snapshot(registry: Node) -> Dictionary:
	if registry == null:
		return {}
	return {
		"deployment": registry.active_deployment_payload.duplicate(true),
		"ledger": registry.audit_ledger.duplicate(true),
	}


func _filesystem_snapshot() -> Array[String]:
	var files: Array[String] = []
	for file_name in DirAccess.get_files_at("user://"):
		files.append(file_name)
	files.sort()
	return files


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS | %s" % label)
	else:
		_failures.append(label)
		push_error("FAIL | %s" % label)


func _finish() -> void:
	print("BIO-LOOP-v0 RESULT | %d/5 PASS | %d FAIL" % [5 - _failures.size(), _failures.size()])
	quit(0 if _failures.is_empty() else 1)
