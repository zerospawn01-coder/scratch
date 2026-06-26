# CRISIS ACTOR VTT P2: Card Lifecycle & Audit Log Implementation Plan

This plan details the implementation of **Card Lifecycle & State Transitions** and **Audit Log Logging** within the Godot-based CRISIS ACTOR VTT Minimal tool. These features will convert the VTT from a simple document viewer/ledger into a rule engine capable of executing scenario rules and logging safety and gameplay history.

## User Review Required

> [!IMPORTANT]
> - **Card Conversion Buttons Placement**: The conversion buttons (e.g., "Make Black", "Make White") will be placed directly within each card's metadata row in the card list. This provides quick access for the GM but increases the visual complexity of the card items.
> - **Injunction/Pause Limits**: `Audit Pause` and `Emergency Injunction` will be managed via gameplay buttons in the right-hand Operations Panel. We will log occurrences, but gameplay enforcement (such as capping `Audit Pause` at 2 times) will be handled procedurally by the GM (VTT will log it without hard locking).

## Proposed Changes

### 1. [MODIFY] [session_state.gd](file:///C:/Users/zeros/.gemini/antigravity/scratch/project_manuals/godot_starter/scripts/session_state.gd)
- **Members**:
  - Add `audit_events: Array[Dictionary] = []` to track gameplay/safety history.
- **Audit Logging**:
  - Implement `func log_audit_event(type: String, details: Dictionary) -> void` to append timestamped audit records.
  - Integrate `audit_events` into history tracking (`_save_history()` and `undo()`) to ensure audit events support Undo/Redo.
  - Update `to_dict()`, `from_dict()`, and JSON save/load to persist `audit_events`.
- **Card Lifecycle Transitions**:
  - Implement `func convert_card(from_type: String, index: int, to_type: String) -> void` to safely move a card from one array to another (e.g., `gray` to `black`), populating relevant fields (title, desc) and logging `CARD_CONVERTED` in the audit events.
- **Markdown Exporter**:
  - Update `export_to_markdown()` to append a "## ■ 監査ログ履歴 (Audit Log)" section displaying all logged events with timestamps.

### 2. [MODIFY] [main.gd](file:///C:/Users/zeros/.gemini/antigravity/scratch/project_manuals/godot_starter/scripts/main.gd)
- **Gameplay Card Controls**:
  - Update `_create_card_ui_node()` to dynamically add small transition buttons to cards based on their type:
    - **Gray (灰) cards**: `[黒カード化]` (to black), `[白カード化]` (to white), `[調査対象化]` (to investigation).
    - **Black (黒) cards**: `[保全中化]` (to protected), `[調査対象化]` (to investigation), `[公開区分化]` (to classification).
    - **Rough (粗) cards**: `[未処理負債+1]` (adds unprocessed debt), `[灰カード化]` (to gray).
    - **Suspicion (疑惑) cards**: `[灰カード化]` (to gray), `[白カード化]` (to white).
- **Safety Kernel UI & Logic**:
  - Add `Audit Pause` button: Log `AUDIT_PAUSE_USED` event and display a temporary warning notification to the GM.
  - Add `Emergency Injunction` button: Decrement `unprocessed_debt` by 1 (clamped to 0) and log `EMERGENCY_INJUNCTION_USED`.
  - Place these safety actions in the operations panel under the phase buttons.

### 3. [MODIFY] [viewer_smoke_test.gd](file:///C:/Users/zeros/.gemini/antigravity/scratch/project_manuals/godot_starter/tests/viewer_smoke_test.gd)
- **Conversion & Audit Verification**:
  - Simulate adding a gray card, clicking its conversion button to convert it to a black card, and verify the card was moved.
  - Simulate Audit Pause and Emergency Injunction button triggers.
  - Assert that the saved/loaded JSON and exported Markdown contain correct audit log event history.

### 4. [MODIFY] [task.md](file:///C:/Users/zeros/.gemini/antigravity/brain/d8fcf14d-3162-426a-8dbc-31c16f9c0a3d/task.md)
- Update checklist items to track VTT P2 Card Lifecycle & Audit Log.

---

## Verification Plan

### Automated Tests
- Run `tests/viewer_smoke_test.gd` headless and ensure `VIEWER_SMOKE_PASS` is reached:
  ```powershell
  Godot_v4.2.2-stable_win64.exe --headless --path . --script res://tests/viewer_smoke_test.gd
  ```
- Run check-only compiles:
  ```powershell
  Godot_v4.2.2-stable_win64.exe --headless --path . -s res://scripts/main.gd --check-only
  Godot_v4.2.2-stable_win64.exe --headless --path . -s res://scripts/session_state.gd --check-only
  ```
