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
signal return_to_lab_requested

## Current expedition resources. Passed to Gene Mixer on lab return.
var expedition_resources: Dictionary = {
	"gene_fragments": 0,  # Raw material for Gene Mixer
	"incident_count": 0,  # Number of observed anomalies this expedition
	"sector_log": [],      # Ordered incident records for Audit provenance
	"contamination_level": 0.0, # Cumulative bio-hazard exposure
	"hazard_index": 1.0   # Current hazard multiplier
}

## Sector definitions — rich parametric hazard and event profiles
const SECTOR_TABLE: Array[Dictionary] = [
	{
		"id": "ZONE-L-01",
		"label": "SECTOR 01 — Containment Corridor",
		"base_yield": 1,
		"hazard_level": 0.10,
		"incident_type": "SPECIMEN_TRACE",
		"description": "Residual gene markers detected on containment walls. Fragment recovered."
	},
	{
		"id": "ZONE-L-02",
		"label": "SECTOR 02 — Cultivation Chamber",
		"base_yield": 2,
		"hazard_level": 0.25,
		"incident_type": "ACTIVE_CULTURE",
		"description": "Unstable culture medium. Two viable gene fragments extracted before purge."
	},
	{
		"id": "ZONE-L-03",
		"label": "SECTOR 03 — Breach Anteroom",
		"base_yield": 1,
		"hazard_level": 0.40,
		"incident_type": "CONTAINMENT_BREACH_TRACE",
		"description": "Prior breach site. Environmental contamination yielded one fragment."
	},
	{
		"id": "ZONE-L-04",
		"label": "SECTOR 04 — Observation Gallery",
		"base_yield": 3,
		"hazard_level": 0.15,
		"incident_type": "ARCHIVE_ACCESS",
		"description": "Legacy archive terminal. Three archived gene sequences recovered."
	},
	{
		"id": "ZONE-L-05",
		"label": "SECTOR 05 — Deep Biosphere Core",
		"base_yield": 3,
		"hazard_level": 0.65,
		"incident_type": "MUTATION_FLARE",
		"description": "Deep biosphere reactor. Hyper-reactive gene fragments discovered under heavy radiation."
	}
]

var _current_sector_index: int = 0

## Execute a single sector exploration with optional operator directive [HARVEST / PURGE / DEEP_SCAN]
func explore_next_sector(directive: String = "HARVEST") -> Dictionary:
	var sector = SECTOR_TABLE[_current_sector_index % SECTOR_TABLE.size()]
	_current_sector_index += 1

	var base_yield: int = sector.get("base_yield", 1)
	var hazard: float = sector.get("hazard_level", 0.1)
	var yield_mod: int = 0
	
	match directive:
		"DEEP_SCAN":
			# Increase yield at the cost of higher contamination
			yield_mod = 1
			expedition_resources["contamination_level"] = clampf(expedition_resources["contamination_level"] + hazard * 1.5, 0.0, 1.0)
		"PURGE":
			# Reduce hazard exposure at minimal yield
			yield_mod = -1 if base_yield > 1 else 0
			expedition_resources["contamination_level"] = clampf(expedition_resources["contamination_level"] * 0.5, 0.0, 1.0)
		_: # "HARVEST"
			expedition_resources["contamination_level"] = clampf(expedition_resources["contamination_level"] + hazard, 0.0, 1.0)

	var fragment_yield: int = maxi(base_yield + yield_mod, 1)
	expedition_resources["gene_fragments"] += fragment_yield
	expedition_resources["incident_count"] += 1
	expedition_resources["hazard_index"] = 1.0 + (expedition_resources["contamination_level"] * 0.8)

	var incident: Dictionary = {
		"sector_id": sector.get("id", "UNKNOWN"),
		"incident_type": sector.get("incident_type", "UNKNOWN"),
		"description": sector.get("description", ""),
		"directive": directive,
		"fragments_recovered": fragment_yield,
		"running_total": expedition_resources["gene_fragments"],
		"contamination_level": expedition_resources["contamination_level"],
		"hazard_index": expedition_resources["hazard_index"],
		"timestamp": Time.get_datetime_string_from_system()
	}
	expedition_resources["sector_log"].append(incident)

	print("[Expedition] Sector explored: %s (Directive: %s)" % [sector.get("id"), directive])
	print("  Incident: %s" % incident["incident_type"])
	print("  Fragments recovered: +%d (total: %d, contamination: %.2f)" % [
		fragment_yield, expedition_resources["gene_fragments"], expedition_resources["contamination_level"]
	])

	sector_explored.emit(incident)
	resources_updated.emit(expedition_resources.duplicate(true))
	return incident

## Hand off expedition resources to Gene Mixer and return to lab.
## Caller is responsible for reading the returned resource dict and
## passing gene_fragments to the Gene Mixer UI.
func return_to_lab() -> Dictionary:
	var handoff: Dictionary = expedition_resources.duplicate(true)
	print("\n[Expedition] Returning to lab.")
	print("  Total fragments: %d" % handoff["gene_fragments"])
	print("  Incidents observed: %d" % handoff["incident_count"])
	print("  Contamination level: %.2f" % handoff["contamination_level"])
	# Reset for next expedition
	expedition_resources = {
		"gene_fragments": 0,
		"incident_count": 0,
		"sector_log": [],
		"contamination_level": 0.0,
		"hazard_index": 1.0
	}
	_current_sector_index = 0
	return_to_lab_requested.emit()
	return handoff

## Query current resources without side effects (read-only)
func get_resources() -> Dictionary:
	return expedition_resources.duplicate(true)

