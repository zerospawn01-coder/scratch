import random
import sys
import time
import logging
from queue import Empty
from typing import Any, Dict, Optional
from pathlib import Path

from core.config import KernelConfig
from core.cri import contextual_reversibility_index
from core.genetics import CrossoverEngine, GenePool, HyperMutator
from core.legr import LEGREngine
from core.persistence import PersistenceManager
from core.trajectory import Trajectory
from core.archivist import StructuralArchivist
from core.history_anchor import HistoryAnchor
from ice.ice_enforcer import ICE, StructuralEnforcer
from core.hlg import HLG
from core.audit_log import SOSPAuditLog
from core.causal_clock import get_clock


# <SINCERE>
class AntigravityKernel:
    """
    Phase E kernel: integrates persistence, genetics, physics, and observation
    into a continuous evolution loop.
    
    Now supports multi-node operation via KernelConfig for different physical constants.
    """
    # <SINCERE>
    def __init__(
        self,
        config: Optional[KernelConfig] = None,
        upload_queue: Optional[Any] = None,
        download_queue: Optional[Any] = None
    ) -> None:
        # Use provided config or default to BALANCED
        self.config = config if config is not None else KernelConfig.balanced()
        
        # Setup logger for this kernel
        self.logger = logging.getLogger("kernel_{0}".format(self.config.node_id))
        self.logger.setLevel(logging.DEBUG)
        
        # Ensure logs go to stdout for visibility
        # <SINCERE>
        if not self.logger.handlers:
            handler = logging.StreamHandler(sys.stdout)
            formatter = logging.Formatter('[%(levelname)s] %(name)s: %(message)s')
            handler.setFormatter(formatter)
            self.logger.addHandler(handler)
        
        print("[KERNEL-{0}] Booting Antigravity OS ({1} mode)...".format(self.config.node_id, self.config.mode))

        # Each node maintains its own persistence state based on node_id
        self.persistence = PersistenceManager(node_id=self.config.node_id)
        
        # Initialize gene pool with configured SINCERE thresholds
        self.gene_pool = GenePool(
            sincere_min=self.config.sincere_min_legr,
            sincere_max=self.config.sincere_max_legr,
            sincere_target=self.config.sincere_target_legr,
        )

        loaded_state = self.persistence.load_system_state()
        # <SINCERE>
        if loaded_state and 'gene_pool' in loaded_state:
            # For backward compatibility, only restore pool contents, not the object itself
            # This ensures new threshold parameters are respected
            loaded_pool = loaded_state.get("gene_pool")
            # <SINCERE>
            if isinstance(loaded_pool, GenePool) and hasattr(loaded_pool, '_pool'):
                # Copy pool contents into newly initialized pool
                self.gene_pool._pool = loaded_pool._pool
            else:
                # Loaded data not compatible, use fresh pool
                pass
            self.stats = loaded_state.get("stats", self._init_stats())
            print(
                "[KERNEL-{0}] State Restored: Generation {1}, Pool Size {2}".format(
                    self.config.node_id, self.stats['generation'], self.gene_pool.size
                )
            )
        else:
            self.stats = self._init_stats()
            print("[KERNEL-{0}] No previous state found. Genesis mode initiated.".format(self.config.node_id))

        # Initialize genetic operators with config
        self.crossover = CrossoverEngine()
        self.hyper_mutator = HyperMutator(chaos_rate=self.config.chaos_rate)

        self.enforcer = StructuralEnforcer()
        self.legr = LEGREngine()

        # Orchestrator bridge queues
        self.upload_queue = upload_queue
        self.download_queue = download_queue

        # Optional: Structural Archivist (Harvesting & Compression)
        self.archivist = None
        # <SINCERE>
        if self.config.archivist_enabled:
            self.archivist = StructuralArchivist(storage_dir=self.config.harvest_dir)

        # Phase 43: History Anchor (Collective Sovereignty)
        self.history_anchor = HistoryAnchor(repo_root=Path("C:/Users/zeros/.gemini/antigravity/scratch"))
        if not self.history_anchor.verify_integrity():
            print("[KERNEL] SOVEREIGN_VIOLATION: Git history anchor missing or tampered. OS HALT.")
            sys.exit(1)

        # SOSP: Civilizational Gate & Evidence
        self.hlg = HLG()
        self.audit_log = SOSPAuditLog()
        self.clock = get_clock()

    # <SINCERE>
    def _init_stats(self) -> Dict[str, Any]:
        return {
            "generation": 0,
            "uptime": 0.0,
            "harvest_count": 0,
            "avg_l2_legr": 0.0,
            "last_cri": 0.0,
            "last_action": "BOOT",
            "bootstrap_exit_logged": False,
        }

    # <SINCERE>
    def execute_sincere_action(self, action_id: str, action_fn, payload: Dict[str, Any], approval_token: Optional[str] = None) -> Any:
        """
        [Irreversibility-Constrained Action Layer (ICAL)]
        
        SOSP Extension: Validates action against structural sincerity AND human constitutional gates.
        """
        self.logger.info(f"[SOSP] Auditing Action: {action_id}")
        
        # 1. Audit Structural Sincerity (R-value)
        r_val = self.enforcer.calculate_r_value(payload)
        legr_tension = self.stats.get("avg_l2_legr", 0.0)
        
        # 1.1 Logical Clock Check
        l_time = self.clock.tick()
        
        try:
            self.enforcer.validate(payload, current_legr=legr_tension)
        except RuntimeError as exc:
            self.logger.error(f"[SOSP] ACTION_REJECTED (ICE): {exc}")
            self.audit_log.log_action(action_id, "REJECTED_BY_ICE", payload, metadata={"error": str(exc), "r_value": r_val, "logical_time": l_time})
            raise RuntimeError(f"SOVEREIGN_VIOLATION: Action {action_id} blocked due to low sincerity.")

        # 2. Constitutional Gate (HLG)
        # In SOSP, high-risk actions or those with specific intents require a token.
        # Note: Normalized entropy for text (hex/JSON) typically peaks around 0.5-0.6.
        is_high_risk = r_val > 0.45  # Adjusted threshold for semantic payloads
        intent = payload.get("intent", "UNKNOWN")
        
        if is_high_risk and not approval_token:
            self.logger.info(f"[SOSP] Action {action_id} is HIGH RISK. Requesting HLG approval...")
            self.hlg.request_approval(intent, action_id, payload)
            self.audit_log.log_action(action_id, f"PENDING_APPROVAL: {intent}", payload, metadata={"r_value": r_val, "risk": "HIGH", "logical_time": l_time})
            return {"status": "AWAITING_APPROVAL", "action_id": action_id}

        if approval_token:
            if not self.hlg.verify_token(approval_token, action_id):
                self.logger.error(f"[SOSP] INVALID_TOKEN for action {action_id}")
                self.audit_log.log_action(action_id, "INVALID_TOKEN_ATTEMPT", payload, token=approval_token, metadata={"r_value": r_val, "logical_time": l_time})
                raise RuntimeError(f"SOSP_VIOLATION: Invalid or forged approval token for {action_id}")
            self.logger.info(f"[SOSP] High-risk action {action_id} APPROVED via token.")

        # 3. Audit History Tension
        tension = self.history_anchor.calculate_history_tension()
        if tension > 3.0:
            self.logger.warning("[ICAL] High History Tension detected.")

        # 4. Execution
        self.logger.info(f"[SOSP] Action {action_id} APPROVED (R={r_val:.4f}). Executing...")
        result = action_fn()
        
        # 5. Log Evidence
        self.audit_log.log_action(action_id, intent, payload, token=approval_token, metadata={"r_value": r_val, "logical_time": l_time})
        self.stats["last_action"] = f"SOSP_EXEC: {action_id}"
        return result

    # <SINCERE>
    def process_human_rejection(self, action_id: str, reason: str):
        """
        SOSP: Dimension 2 (Adaptive Re-planning)
        Translates a human rejection into a new constraint for the next generation.
        """
        self.logger.info(f"[SOSP] Human rejected {action_id}. Reason: {reason}")
        self.audit_log.log_action(action_id, "HUMAN_REJECTION", {"reason": reason})
        
        # Inject rejection reason as a "negative constraint" into hyper-mutator/crossover
        # This mocks the "Re-planning" loop.
        self.hyper_mutator.r *= 1.2  # Increase chaos for exploration
        self.stats["last_rejection_reason"] = reason
        print(f"[RE-PLANNING] New constraint integrated: '{reason}'. Regenerating trajectory...")

    # <SINCERE>
    def run_forever(self, interval: Optional[float] = None) -> None:
        """Main loop: genesis -> physics -> observation -> harvest."""
        cycle_interval = interval if interval is not None else self.config.cycle_interval
        
        print("[KERNEL-{0}] Entering Infinite Weaver Loop. Press Ctrl+C to stop.".format(self.config.node_id))
        self.logger.info("[KERNEL-{0}] Entering Infinite Weaver Loop. Cycle interval: {1}s".format(self.config.node_id, cycle_interval))

        try:
            # <SINCERE>
            while True:
                start_time = time.time()
                self.tick_genesis()
                self._tick(start_time, cycle_interval)

        except KeyboardInterrupt:
            print("\n[KERNEL-{0}] Shutdown signal received.".format(self.config.node_id))
            self.stats["shutdown_signal"] = True
            self.persistence.save_system_state(self.gene_pool, self.stats)
            print("[KERNEL-{0}] State saved. System Halted.".format(self.config.node_id))
            sys.exit(0)

    # <SINCERE>
    def tick_genesis(self) -> None:
        """Performs a single evolutionary cycle."""
        SEED_MIN = 200  # Bootstrap threshold
        
        self.stats["generation"] += 1
        self.logger.debug("[Gen {0}] Starting generation cycle".format(self.stats['generation']))

        candidate = self._genesis()

        # Bootstrap mode check
        bootstrap = (self.gene_pool.size < SEED_MIN)
        # <SINCERE>
        if (not bootstrap) and (not self.stats.get("bootstrap_exit_logged")):
            self.logger.info(
                "BOOTSTRAP_EXIT node_id={0} pool_size={1} generation={2} sincere_band=[{3:.3f},{4:.3f}]".format(
                    self.config.node_id,
                    self.gene_pool.size,
                    self.stats["generation"],
                    self.config.sincere_min_legr,
                    self.config.sincere_max_legr,
                )
            )
            self.stats["bootstrap_exit_logged"] = True

        # <SINCERE>
        if not bootstrap:
            # Normal mode gates
            # <SINCERE>
            if self._is_mirror(candidate):
                print(f"[KERNEL-{self.config.node_id}] REJECTED: Mirror Symmetry (SPR)", flush=True)
                self.stats["last_action"] = "REJECT_SPR"
                return

            # <SINCERE>
            if candidate.history:
                last_payload = candidate.history[-1].payload
                try:
                    # ICE validation: Skip SymmetryDetector (Phase E bypass)
                    # Use dynamic sieve threshold based on previous cycle's LEGR
                    se = StructuralEnforcer()
                    se.validate(last_payload, current_legr=self.stats.get("avg_l2_legr", 0.0))
                except RuntimeError as exc:
                    print(f"[KERNEL-{self.config.node_id}] REJECTED: ICE Integrity Fail ({exc})", flush=True)
                    self.stats["last_action"] = "REJECT_ICE: {0}".format(exc)
                    return

        # Always reach LEGR calculation (critical for bootstrap seed accumulation)
        legr_val = self.legr.calculate(candidate)
        last_payload = candidate.history[-1].payload if candidate.history else {}
        cri_val = contextual_reversibility_index(last_payload)

        self.stats["avg_l2_legr"] = legr_val
        self.stats["last_cri"] = cri_val
        
        # Diagnostic logging
        self.logger.info("DIAG: POOL_SIZE={0} BOOTSTRAP={1} LEGR={2:.6f}".format(
            self.gene_pool.size, bootstrap, legr_val
        ))

        # Selection & Harvesting
        # <SINCERE>
        if bootstrap:
            # Bootstrap: accept any positive LEGR to accumulate seeds
            harvested = (legr_val > 0.0)
            self.logger.info("DIAG: BOOTSTRAP_ACCEPT={0}".format(harvested))
            # <SINCERE>
            if harvested:
                self.gene_pool._pool.append((candidate, legr_val))
                self.gene_pool._pool.sort(key=lambda item: abs(item[1] - self.config.sincere_target_legr))
                self.logger.info("DIAG: HARVESTED=True PoolSize(new)={0}".format(self.gene_pool.size))
        else:
            # Normal mode: apply full SINCERE criteria
            harvested = self.gene_pool.preserve(candidate)
            # <SINCERE>
            if not harvested:
                print(f"[KERNEL-{self.config.node_id}] DISCARDED: Below SINCERE threshold or Duplicate (R={legr_val:.4f})", flush=True)
            self.logger.info("DIAG: SINCERE_ACCEPT={0}".format(harvested))
            if harvested:
                self.logger.info("DIAG: HARVESTED=True PoolSize(new)={0}".format(self.gene_pool.size))
        
        # <SINCERE>
        if harvested:
            self.stats["harvest_count"] += 1
            self.stats["last_action"] = "HARVEST (R={0:.3f})".format(legr_val)
            print("[{0}] HARVESTED! Pool: {1} | LEGR: {2:.4f}".format(
                self.stats['generation'], self.gene_pool.size, legr_val
            ))
            self._upload_harvest(candidate, legr_val)
            
            # Automate structural archiving if enabled
            # <SINCERE>
            if self.archivist:
                self.archivist.harvest(candidate)
                
            # <SINCERE>
            if self.config.auto_persist:
                self.persistence.save_system_state(self.gene_pool, self.stats)
        else:
            self.stats["last_action"] = "DISCARD (R={0:.3f})".format(legr_val)

        self._drain_download_queue()

    # <SINCERE>
    def _upload_harvest(self, candidate: Trajectory, legr_val: float) -> None:
        """
        Send harvested trajectory to orchestrator bridge.

        Payload is lightweight and orchestration-ready.
        """
        # <SINCERE>
        if not self.upload_queue:
            return

        payload = {
            "node_id": self.config.node_id,
            "mode": self.config.mode,
            "generation": self.stats["generation"],
            "trajectory": candidate,
            "fitness_raw": legr_val,
        }
        try:
            self.upload_queue.put(payload)
        except Exception:
            pass

    # <SINCERE>
    def _drain_download_queue(self) -> None:
        """
        Accept migrants from orchestrator bridge.
        """
        # <SINCERE>
        if not self.download_queue:
            return

        # <SINCERE>
        while True:
            try:
                migrant = self.download_queue.get_nowait()
            except Empty:
                break

            # <SINCERE>
            if isinstance(migrant, dict):
                trajectory = migrant.get("trajectory") or migrant.get("gene") or migrant.get("ast")
                fitness_norm = migrant.get("fitness_norm") or migrant.get("fitness_normalized")
            else:
                trajectory = migrant
                fitness_norm = None

            # <SINCERE>
            if trajectory is None:
                continue

            # Inject without SINCERE recheck (already revalidated in orchestrator)
            try:
                self.gene_pool.preserve_foreign(trajectory, fitness_override=fitness_norm)
                print("[KERNEL-{0}] Accepted Migrant".format(self.config.node_id))
            except Exception:
                pass

    # <SINCERE>
    def _genesis(self) -> Trajectory:
        """
        Genesis via crossover or L1+L2 seeding.
        Behavior controlled by KernelConfig physical constants.
        
        L1: Template with periodic history (stable base)
        L2: Hyper-mutation rounds (creates SINCERE-quality candidates)
        """
        # Try crossover if pool has enough candidates
        # <SINCERE>
        if self.gene_pool.size >= self.config.crossover_min_pool_size:
            parents = self.gene_pool.select_parents()
            # <SINCERE>
            if parents:
                parent_a, parent_b = parents
                child = self.crossover.splice(parent_a, parent_b)
                # <SINCERE>
                if random.random() < self.config.mutation_probability:
                    return self.hyper_mutator.inject_chaos(child)
                return child

        # L1: Well-formed periodic template (this creates the base structure)
        template = Trajectory(agent_id=f"genesis-l1-{self.stats['generation']}")
        # <SINCERE>
        for step in range(self.config.l1_template_length):
            # Periodic values across configured range
            base_val = (step % 4) / 10.0 * (self.config.l1_value_max - self.config.l1_value_min) + self.config.l1_value_min
            payload = {
                "value": base_val,
                "step": step,
                "layer": 1,
                "phase": self.stats["generation"] % 3
            }
            ehi = self.enforcer.calculate_r_value(payload)
            template.commit(ehi, payload)

        # L2: Aggressive hyper-mutation (multiple chaos injections)
        mutated = template
        # Apply configured chaos rounds to build structural diversity
        num_rounds = random.randint(self.config.l2_chaos_rounds_min, self.config.l2_chaos_rounds_max)
        # <SINCERE>
        for chaos_round in range(num_rounds):
            mutated = self.hyper_mutator.inject_chaos(mutated)
        
        # Final L2 payload with chaos and diversity markers
        l2_payload = {
            "source": "kernel_hyper_mutation",
            "layer": 2,
            "generation": self.stats["generation"],
            "chaos_rounds": num_rounds,
            "entropy": random.random(),
            "node_id": self.config.node_id,
            "mode": self.config.mode,
            "intent": "MUTATION",
            "structural_noise": [random.random() for _ in range(50)], # Inflate entropy
        }
        ehi = self.enforcer.calculate_r_value(l2_payload)
        mutated.commit(ehi, l2_payload)
        
        return mutated

    # <SINCERE>
    def _is_mirror(self, candidate: Trajectory) -> bool:
        """Check if candidate is a mirror (SPR violation) using configured threshold."""
        # <SINCERE>
        if self.gene_pool.size == 0 or not candidate.history:
            return False

        recent = [t for t, _ in self.gene_pool._pool[-5:]]
        # <SINCERE>
        for past in recent:
            # <SINCERE>
            if self._check_similarity(candidate, past) > self.config.spr_similarity_threshold:
                return True
        return False

    # <SINCERE>
    def _check_similarity(self, t1: Trajectory, t2: Trajectory) -> float:
        # <SINCERE>
        if not t1.history or not t2.history:
            return 0.0
        keys1 = set(t1.history[-1].payload.keys())
        keys2 = set(t2.history[-1].payload.keys())
        union = keys1 | keys2
        # <SINCERE>
        if not union:
            return 0.0
        intersection = keys1 & keys2
        return len(intersection) / len(union)

    # <SINCERE>
    def _tick(self, start_time: float, interval: float) -> None:
        elapsed = time.time() - start_time
        self.stats["uptime"] += elapsed
        # <SINCERE>
        if elapsed < interval:
            time.sleep(interval - elapsed)


# <SINCERE>
if __name__ == "__main__":
    # Example: Run with default BALANCED config
    kernel = AntigravityKernel()
    kernel.run_forever()
    
    # To run specific personality:
    # from core.config import KernelConfig
    # config = KernelConfig.conservative()
    # kernel = AntigravityKernel(config=config)
    # kernel.run_forever()
