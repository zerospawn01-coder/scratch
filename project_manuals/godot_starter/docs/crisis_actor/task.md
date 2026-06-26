# CRISIS ACTOR VTT P2: Card Lifecycle & Audit Log Checklist

- `[ ]` 1. Modify `session_state.gd`
  - `[ ]` Add `audit_events: Array[Dictionary]` member
  - `[ ]` Implement `log_audit_event(type: String, details: Dictionary)`
  - `[ ]` Integrate `audit_events` into history undo/redo stack
  - `[ ]` Update JSON save/load for `audit_events`
  - `[ ]` Implement `convert_card(from_type: String, index: int, to_type: String)`
  - `[ ]` Update Markdown exporter `export_to_markdown()` to append audit history
- `[ ]` 2. Modify `main.gd`
  - `[ ]` Add transition buttons inside `_create_card_ui_node()` based on card type
  - `[ ]` Connect buttons to call `state.convert_card()`
  - `[ ]` Add `Audit Pause` and `Emergency Injunction` safety action buttons
  - `[ ]` Connect safety buttons to log audit events and execute logic (e.g. unprocessed_debt reduction)
- `[ ]` 3. Update `viewer_smoke_test.gd`
  - `[ ]` Add smoke test actions for card conversion (e.g. gray to black)
  - `[ ]` Add smoke test actions for Audit Pause and Emergency Injunction
  - `[ ]` Verify audit log presence in saved JSON and exported Markdown
- `[ ]` 4. Run verification and obtain VIEWER_SMOKE_PASS
