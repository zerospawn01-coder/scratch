# CRISIS ACTOR VTT P2: Card Lifecycle & Audit Log Checklist

- `[x]` 1. Modify `session_state.gd`
  - `[x]` Add `audit_events: Array[Dictionary]` member
  - `[x]` Implement `log_audit_event(type: String, details: Dictionary)`
  - `[x]` Integrate `audit_events` into history undo/redo stack
  - `[x]` Update JSON save/load for `audit_events`
  - `[x]` Implement `convert_card(from_type: String, index: int, to_type: String)`
  - `[x]` Update Markdown exporter `export_to_markdown()` to append audit history
- `[x]` 2. Modify `main.gd`
  - `[x]` Add transition buttons inside `_create_card_ui_node()` based on card type
  - `[x]` Connect buttons to call `state.convert_card()`
  - `[x]` Add `Audit Pause` and `Emergency Injunction` safety action buttons
  - `[x]` Connect safety buttons to log audit events and execute logic (e.g. unprocessed_debt reduction)
- `[x]` 3. Update `viewer_smoke_test.gd`
  - `[x]` Add smoke test actions for card conversion (e.g. gray to black)
  - `[x]` Add smoke test actions for Audit Pause and Emergency Injunction
  - `[x]` Verify audit log presence in saved JSON and exported Markdown
- `[x]` 4. Run verification and obtain VIEWER_SMOKE_PASS
