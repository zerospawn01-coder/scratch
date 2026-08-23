extends Node

# =============================================================================
# Aether Fountain — ZONE-Λ Expedition Manager (Minimum Integration v0)
# Principle: generation_is_not_authority
# Exploration does NOT create bioroids. It only surfaces raw gene fragments
# for the Gene Mixer to process. The loop is:
#   Exploration -> Resource Acquisition -> Gene Mixer -> Arena -> Audit Log -> Exploration
# =============================================================================

signal sector_explored(incident: Dictionary)
signal resources_updated(resources: Dictionary)
signal decision_resolved(result: Dictionary)
signal return_to_lab_requested

## Current expedition resources. Passed to Gene Mixer on lab return.
var expedition_resources: Dictionary = {
	"gene_fragments": 0,  # Raw material for Gene Mixer
	"incident_count": 0,  # Number of observed anomalies this expedition
	"sector_log": []       # Ordered incident records for Audit provenance
}

## Expedition Decision State (v0)
## Restricts each expedition cycle to at most 1 decision point (SECURE vs PUSH)
var decision_status: String = "NONE" # "NONE", "PENDING", "SECURED", "PUSH_SUCCESS", "PUSH_HAZARD"
var has_decided_this_run: bool = false

## Sector definitions — minimal, no gameplay scripting beyond resource yield
const SECTOR_TABLE: Array[Dictionary] = [
	{
		"id": "ZONE-L-01",
		"label": "SECTOR 01 — Containment Corridor",
		"fragment_yield": 1,
		"incident_type": "SPECIMEN_TRACE",
		"description": "Residual gene markers detected on containment walls. Fragment recovered."
	},
	{
		"id": "ZONE-L-02",
		"label": "SECTOR 02 — Cultivation Chamber",
		"fragment_yield": 2,
		"incident_type": "ACTIVE_CULTURE",
		"description": "Unstable culture medium. Two viable gene fragments extracted before purge."
	},
	{
		"id": "ZONE-L-03",
		"label": "SECTOR 03 — Breach Anteroom",
		"fragment_yield": 1,
		"incident_type": "CONTAINMENT_BREACH_TRACE",
		"description": "Prior breach site. Environmental contamination yielded one fragment."
	},
	{
		"id": "ZONE-L-04",
		"label": "SECTOR 04 — Observation Gallery",
		"fragment_yield": 3,
		"incident_type": "ARCHIVE_ACCESS",
		"description": "Legacy archive terminal. Three archived gene sequences recovered."
	},
]

var _current_sector_index: int = 0

## Execute a single sector exploration. Returns the incident record.
func explore_next_sector() -> Dictionary:
	var sector = SECTOR_TABLE[_current_sector_index % SECTOR_TABLE.size()]
	_current_sector_index += 1

	var fragment_yield: int = sector.get("fragment_yield", 1)
	expedition_resources["gene_fragments"] += fragment_yield
	expedition_resources["incident_count"] += 1

	var incident: Dictionary = {
		"sector_id": sector.get("id", "UNKNOWN"),
		"incident_type": sector.get("incident_type", "UNKNOWN"),
		"description": sector.get("description", ""),
		"fragments_recovered": fragment_yield,
		"running_total": expedition_resources["gene_fragments"],
		"timestamp": Time.get_datetime_string_from_system()
	}
	expedition_resources["sector_log"].append(incident)

	print("[Expedition] Sector explored: %s" % sector.get("id"))
	print("  Incident: %s" % incident["incident_type"])
	print("  Fragments recovered: +%d (total: %d)" % [fragment_yield, expedition_resources["gene_fragments"]])

	sector_explored.emit(incident)
	resources_updated.emit(expedition_resources.duplicate(true))
	return incident

## Resolve the single-choice decision for the current expedition (v0)
## Choices:
##   "SECURE": Lock in current fragments with 0 risk.
##   "PUSH": Incur a deterministic risk/reward roll based on explicit run_seed.
## Constraints: Max 1 decision per expedition run (subsequent calls fail-closed).
func resolve_decision(choice: String, run_seed: int = 0) -> Dictionary:
	if has_decided_this_run:
		push_warning("[Expedition] Decision already resolved for this cycle (%s). Rejecting repeated decision." % decision_status)
		return {
			"status": "REJECTED_ALREADY_DECIDED",
			"delta_fragments": 0,
			"total_fragments": expedition_resources["gene_fragments"],
			"choice": choice
		}

	has_decided_this_run = true
	var upper_choice = choice.to_upper()
	var delta: int = 0
	var outcome_status: String = ""

	if upper_choice == "SECURE":
		delta = 0
		outcome_status = "SECURED"
		decision_status = "SECURED"
		print("[Expedition Decision] SECURE chosen — Locked %d fragments." % expedition_resources["gene_fragments"])
	elif upper_choice == "PUSH":
		var rng = RandomNumberGenerator.new()
		if run_seed != 0:
			rng.seed = run_seed
		else:
			# Fallback deterministic seed derived from fragments and incidents
			rng.seed = abs(("%d_%d" % [expedition_resources["gene_fragments"], expedition_resources["incident_count"]]).hash())

		var roll = rng.randf()
		# Threshold: >= 0.40 yields bonus fragments (+2), < 0.40 hazard loss (-1, min 0)
		if roll >= 0.40:
			delta = 2
			outcome_status = "PUSH_SUCCESS"
			decision_status = "PUSH_SUCCESS"
			expedition_resources["gene_fragments"] += delta
			print("[Expedition Decision] PUSH SUCCESS (roll: %.3f) — Gained +%d fragments (total: %d)." % [
				roll, delta, expedition_resources["gene_fragments"]
			])
		else:
			delta = -1
			outcome_status = "PUSH_HAZARD"
			decision_status = "PUSH_HAZARD"
			expedition_resources["gene_fragments"] = maxi(expedition_resources["gene_fragments"] + delta, 0)
			print("[Expedition Decision] PUSH HAZARD (roll: %.3f) — Anomaly contamination lost %d fragment (total: %d)." % [
				roll, abs(delta), expedition_resources["gene_fragments"]
			])
	else:
		outcome_status = "INVALID_CHOICE"
		has_decided_this_run = false
		push_error("[Expedition Decision] Unknown choice: %s" % choice)

	var result = {
		"status": outcome_status,
		"delta_fragments": delta,
		"total_fragments": expedition_resources["gene_fragments"],
		"choice": upper_choice
	}

	decision_resolved.emit(result)
	resources_updated.emit(expedition_resources.duplicate(true))
	return result

## Hand off expedition resources to Gene Mixer and return to lab.
## Caller is responsible for reading the returned resource dict and
## passing gene_fragments to the Gene Mixer UI.
func return_to_lab() -> Dictionary:
	var handoff: Dictionary = expedition_resources.duplicate(true)
	handoff["decision_status"] = decision_status
	print("\n[Expedition] Returning to lab.")
	print("  Total fragments: %d" % handoff["gene_fragments"])
	print("  Incidents observed: %d" % handoff["incident_count"])
	print("  Decision Status: %s" % decision_status)
	# Reset for next expedition
	expedition_resources = {
		"gene_fragments": 0,
		"incident_count": 0,
		"sector_log": []
	}
	_current_sector_index = 0
	decision_status = "NONE"
	has_decided_this_run = false
	return_to_lab_requested.emit()
	return handoff

## Query current resources without side effects (read-only)
func get_resources() -> Dictionary:
	return expedition_resources.duplicate(true)

