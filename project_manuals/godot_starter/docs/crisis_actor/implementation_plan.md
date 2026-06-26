# CRISIS ACTOR VTT P2: Card Lifecycle & Audit Log Implementation Plan

This plan details the implementation of **Card Lifecycle & State Transitions** and **Audit Log Logging** within the Godot-based CRISIS ACTOR VTT Minimal tool. These features will convert the VTT from a simple document viewer/ledger into a rule engine capable of executing scenario rules and logging safety and gameplay history.

P2では、カード変換は単なる配列移動ではなく、監査可能な状態遷移として扱う。
すべての変換は、変換元、変換先、対象カード名、実行理由を audit_events に記録する。
安全確認は全PL向け、Audit Pauseはオーディター補助、Emergency Injunctionは対象カードを保全するゲーム内監査権限としてUI上でも分離する。

## User Review Required

> [!IMPORTANT]
> - **Audit Log Undo Policy**: The VTT's audit log is strictly append-only. Performing an `undo` operation does not remove logged audit events; instead, it appends a new `AUDIT_EVENT_REVERTED` log entry. This ensures permanent auditable trace of all VTT operations while allowing GMs/Auditors to revert incorrect card placements or clock adjustments.
> - **Injunction/Pause Limits**: `Audit Pause` and `Emergency Injunction` will be managed via gameplay buttons/indicators in the right-hand Operations Panel. We will log occurrences and display their usage counters, but gameplay enforcement (such as capping `Audit Pause` at 2 times) will be handled procedurally by the GM (VTT will log it without hard locking).
> - **Target-Card Emergency Injunction**: The general "Emergency Injunction" button in the Operations Panel does not directly decrement unprocessed debt. Instead, GMs must click the `[緊急差止]` button directly on a Black card to convert it to "Protected" (保全中), which decrements `unprocessed_debt` by 1, increments `emergency_injunctions_used` by 1, and records `EMERGENCY_INJUNCTION_USED` in the audit log.
> - **Card UI Buttons & Confirmations**: Small Japanese rule language buttons will be added to cards. Dialog confirmation prompts will guard dangerous operations:
>   - Converting a Black card to a White card (`[白カード化]`)
>   - Converting a Black card to a Public Classification card (`[公開区分化]`)
>   - Deleting a Protected card (`×` button)

## Proposed Changes

### 1. [MODIFY] [session_state.gd](file:///C:/Users/zeros/.gemini/antigravity/scratch/project_manuals/godot_starter/scripts/session_state.gd)
- **Members**:
  - Add/ensure `audit_events: Array[Dictionary] = []` to track gameplay/safety history.
  - Add/ensure `safety_checks_used`, `audit_pauses_used`, and `emergency_injunctions_used` to track safety usage counts.
- **Audit Logging**:
  - Implement `func log_audit_event(type: String, details: Dictionary) -> void` to append timestamped audit records.
  - Keep `audit_events` strictly append-only (do not snapshot it in `_save_history()` or clear/restore it in `undo()`).
  - Update `undo()` to log `AUDIT_EVENT_REVERTED` with details of the undo event.
  - Update `to_dict()`, `from_dict()`, and JSON save/load to persist `audit_events` and the safety counters.
- **Card Lifecycle Transitions**:
  - Implement `func convert_card(from_type: String, index: int, to_type: String) -> void` to safely move a card from one array to another (e.g., `gray` to `black`), populating relevant fields (title, desc) and logging `CARD_CONVERTED` in the audit events.
  - Integrate Emergency Injunction logic within `convert_card()`: when a Black card is converted to Protected, decrement `unprocessed_debt` by 1, increment `emergency_injunctions_used` by 1, and log `EMERGENCY_INJUNCTION_USED` with the card's details.
  - Populate source-destination details for cards:
    - To `black`: If from `gray`, set `source_type = "gray"`, `claim_status = "black_candidate"`
    - To `investigation`: If from `black`, set `source_type = "black"`, `status = "未認定 / 要追加調査"`
    - To `protected`: If from `black`, set `source_type = "black"`, `protected_by = "Emergency Injunction"`
    - To `classification`: If from `black`, set `source_type = "black"`, `public_status = "SEALED / LIMITED / PUBLIC-SAFE"`
- **Markdown Exporter**:
  - Update `export_to_markdown()` to append a "## ■ 監査ログ履歴 (Audit Log)" section displaying all logged events with timestamps and details.
  - Include the safety counters in the Markdown header parameters.
  - Format the extra fields (like `source_type`, `claim_status`, etc.) for outputted cards.

### 2. [MODIFY] [main.gd](file:///C:/Users/zeros/.gemini/antigravity/scratch/project_manuals/godot_starter/scripts/main.gd)
- **Gameplay Card Controls**:
  - Update `_create_card_ui_node()` to dynamically add small Japanese transition buttons to cards:
    - **Gray (灰) cards**: `[黒カード化]` (to black), `[白カード化]` (to white), `[調査対象化]` (to investigation).
    - **Black (黒) cards**: `[緊急差止]` (to protected), `[調査対象化]` (to investigation), `[公開区分化]` (to classification), `[白カード化]` (to white).
    - **Rough (粗) cards**: `[未処理負債+1]` (adds unprocessed debt), `[灰カード化]` (to gray).
    - **Suspicion (疑惑) cards**: `[灰カード化]` (to gray), `[白カード化]` (to white).
  - Add dialog confirmations to `[白カード化]` and `[公開区分化]` actions on Black cards, and deleting a Protected card.
  - Append specific metadata (e.g. `status`, `protected_by`, etc.) to the card UI descriptions if present.
- **Safety Kernel UI & Logic**:
  - Add 3 separated buttons/indicators in the Operations Panel under the phase buttons:
    - `[安全確認 / Safety Check]` button: Increment `safety_checks_used`, log `SAFETY_CHECK_USED`, and show a temporary message.
    - `[Audit Pause]` button: Increment `audit_pauses_used`, log `AUDIT_PAUSE_USED` event, and show a temporary GM notification.
    - `[Emergency Injunction]` button: Inform the GM/Auditor to use the card-specific button instead.
  - Show counters dynamically: e.g. `Safety Check (使用数: N)`, `Audit Pause (使用数: N)`, `Emergency Injunction (使用数: N)`.

### 3. [MODIFY] [viewer_smoke_test.gd](file:///C:/Users/zeros/.gemini/antigravity/scratch/project_manuals/godot_starter/tests/viewer_smoke_test.gd)
- **Conversion & Audit Verification**:
  - Simulate adding a gray card, clicking its `[黒カード化]` button to convert it to a black card, and verify it moved.
  - Simulate clicking `[緊急差止]` on the black card to convert it to protected, verifying `unprocessed_debt` decrements and counters increment.
  - Test safety panel actions (Safety Check, Audit Pause).
  - Assert that the saved/loaded JSON and exported Markdown contain correct audit log event history and safety counters.

### 4. [MODIFY] [task.md](file:///C:/Users/zeros/.gemini/antigravity/brain/d8fcf14d-3162-426a-8dbc-31c16f9c0a3d/task.md)
- Update checklist items to track refined VTT P2 tasks.

---

## Verification Plan

### Automated Tests
- Run `tests/viewer_smoke_test.gd` headless using Godot 4.7:
  ```powershell
  C:\Users\zeros\AppData\Local\Temp\codex-godot-4.7\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/viewer_smoke_test.gd
  ```
- Run check-only compiles:
  ```powershell
  C:\Users\zeros\AppData\Local\Temp\codex-godot-4.7\Godot_v4.7-stable_win64_console.exe --headless --path . -s res://scripts/main.gd --check-only
  C:\Users\zeros\AppData\Local\Temp\codex-godot-4.7\Godot_v4.7-stable_win64_console.exe --headless --path . -s res://scripts/session_state.gd --check-only
  ```
