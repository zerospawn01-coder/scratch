"""
override_observer.py — Phase R: Override Episode Observation

Reads DecisionEvent JSONL rows (from run_loop or ledger.jsonl) and produces a
per-episode summary of every STAGNATION_OVERRIDE / EXPLORATION_EXHAUSTED episode.

Episode lifecycle (detected from exploration_status fields):
    START  → exploration_status.override_active transitions False → True
    END    → exploration_status.override_active transitions True → False
             (may include OVERRIDE_BUDGET_EXCEEDED in policy_violations)

Episode outcome classification:
    budget_exhausted   — policy_violations contains OVERRIDE_BUDGET_EXCEEDED
    improving_escape   — override ended without budget exhaustion; decision == ADOPT
                         and stagnation reset (healthy recovery)
    passive_deactivate — override deactivated but decision was not ADOPT
                         (reject_ratio dropped below threshold on its own)
    run_truncated      — override still active when rows are exhausted

Output: list of OverrideEpisode; serialize via .to_dict() for JSONL/analytics.

Usage:
    rows = run_loop(...)          # from run_loop.py
    episodes = extract_episodes(rows)

    # Or read from a saved ledger:
    episodes = load_episodes_from_ledger(Path("ledger.jsonl"))

    # Emit JSONL report:
    report_to_jsonl(episodes, Path("override_report.jsonl"))
"""
from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, List, Optional


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class OverrideEpisode:
    """Aggregated summary of one override episode."""

    episode_id: int
    """1-based counter within the run (or ledger slice)."""

    start_seq: int
    """seq of the first row where override_active became True."""

    end_seq: int
    """seq of the row where override_active returned to False (or last row if truncated)."""

    trigger_reason: Optional[str]
    """override_reason captured at episode start (STAGNATION_OVERRIDE, EXPLORATION_EXHAUSTED)."""

    budget_used: int
    """override_attempts_used at episode end.  0 if episode never tracked."""

    escape_adopt_count: int
    """Number of ADOPT decisions recorded while override was active in this episode."""

    escape_novel_count: int
    """Number of novel (unique) candidate hashes submitted while override was active."""

    outcome: str
    """
    One of:
      budget_exhausted   — episode consumed the full override_budget
      improving_escape   — candidate was ADOPTed, ending the episode naturally
      passive_deactivate — override deactivated but decision was not ADOPT
      run_truncated      — override still active at end of input rows
    """

    def to_dict(self) -> Dict:
        return asdict(self)


# ---------------------------------------------------------------------------
# Core extraction logic
# ---------------------------------------------------------------------------

def extract_episodes(rows: List[Dict]) -> List[OverrideEpisode]:
    """
    Walk DecisionEvent rows in seq order and return one OverrideEpisode per
    override episode detected in exploration_status.

    :param rows: List of DecisionEvent dicts (in seq order, 1-based).
    :returns:    List of OverrideEpisode; empty if no episodes were found.
    """
    episodes: List[OverrideEpisode] = []
    in_episode: bool = False
    episode_id: int = 0
    episode_start_seq: int = 0
    episode_trigger: Optional[str] = None

    for row in rows:
        es: Dict = row.get("exploration_status", {})
        override_active: bool = bool(es.get("override_active", False))
        override_reason: Optional[str] = es.get("override_reason")
        seq: int = int(row.get("seq", 0))

        if not in_episode and override_active:
            # Episode START: first row where override flipped to True
            in_episode = True
            episode_id += 1
            episode_start_seq = seq
            episode_trigger = override_reason

        elif in_episode and not override_active:
            # Episode END: first row where override returned to False
            violations: List[Dict] = row.get("policy_violations", [])
            budget_exhausted: bool = any(
                v.get("code") == "OVERRIDE_BUDGET_EXCEEDED"
                for v in violations
            )
            decision: str = str(row.get("decision", ""))

            if budget_exhausted:
                outcome = "budget_exhausted"
            elif decision == "ADOPT":
                outcome = "improving_escape"
            else:
                outcome = "passive_deactivate"

            episodes.append(OverrideEpisode(
                episode_id=episode_id,
                start_seq=episode_start_seq,
                end_seq=seq,
                trigger_reason=episode_trigger,
                budget_used=int(es.get("override_attempts_used", 0)),
                escape_adopt_count=int(es.get("escape_adopt_count", 0)),
                escape_novel_count=int(es.get("escape_novel_count", 0)),
                outcome=outcome,
            ))
            in_episode = False
            episode_start_seq = 0
            episode_trigger = None

    # Handle run truncation: override still active when rows are exhausted
    if in_episode and rows:
        last_row = rows[-1]
        last_es: Dict = last_row.get("exploration_status", {})
        episodes.append(OverrideEpisode(
            episode_id=episode_id,
            start_seq=episode_start_seq,
            end_seq=int(last_row.get("seq", 0)),
            trigger_reason=episode_trigger,
            budget_used=int(last_es.get("override_attempts_used", 0)),
            escape_adopt_count=int(last_es.get("escape_adopt_count", 0)),
            escape_novel_count=int(last_es.get("escape_novel_count", 0)),
            outcome="run_truncated",
        ))

    return episodes


# ---------------------------------------------------------------------------
# I/O helpers
# ---------------------------------------------------------------------------

def load_rows_from_ledger(path: Path) -> List[Dict]:
    """Read all non-empty JSONL rows from *path*, returning them in file order."""
    rows: List[Dict] = []
    if not path.exists():
        return rows
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return rows


def load_episodes_from_ledger(path: Path) -> List[OverrideEpisode]:
    """Convenience wrapper: load rows then extract episodes."""
    return extract_episodes(load_rows_from_ledger(path))


def report_to_jsonl(episodes: List[OverrideEpisode], path: Path) -> None:
    """Serialise episodes to a JSONL file (one episode per line)."""
    with path.open("w", encoding="utf-8") as f:
        for ep in episodes:
            f.write(json.dumps(ep.to_dict(), ensure_ascii=True) + "\n")
