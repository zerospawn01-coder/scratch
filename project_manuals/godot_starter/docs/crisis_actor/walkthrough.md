# CRISIS ACTOR: Tabletop Operation Tool (VTT Minimal) Walkthrough

The Godot-based **CRISIS ACTOR VTT Minimal** tool has been successfully updated to include the new custom scenario, **Episode 3: 帳外神楽 (Chougai-Kagura)**, framing regional folklore as a decentralized audit log, along with comprehensive **Session Save/Load** and **Markdown Export** operations.

---

## 1. Episode 3: "帳外神楽" (v0.3 行政ホラー版) Integration
*   **Artifact File**: [crisis_actor_scenario_ep3.md](file:///C:/Users/zeros/.gemini/antigravity/brain/d8fcf14d-3162-426a-8dbc-31c16f9c0a3d/crisis_actor_scenario_ep3.md)
*   **VTT Documentation Copy**: [crisis_actor_scenario_ep3.md (Project Copy)](file:///C:/Users/zeros/.gemini/antigravity/scratch/project_manuals/godot_starter/docs/crisis_actor/crisis_actor_scenario_ep3.md)
*   **Details**:
    - **コンセプトの極大化**: 「祟りや怪異」ではなく、「死者の名前を資料分類・観光資源へと事務的に処理・消去していく行政の無機質な暴力」をホラーの核に据えました。
    - **「異物フレーム」カードの追加**: 旧「面の子」のオカルト的描写を廃し、鈴の音の周波数干渉や編集ミス、村人の作為による機材ノイズ（灰カード）に変更し、処理テーブル（機材/編集ミス/仕込み/演出）を追加。
    - **陰謀論配信者ノゾミの再定義**: プレイヤーの推理を奪わないよう、的外れな主張と本物の「一次データ」を併せ持つ「扱いに困る素材散布装置」へ再設計。疑惑カードにも「的外れな結論」と「一次データ」の書式を導入。
    - **選択肢A（白カード化）での実体験**: プレイヤー自身に「展示解説文」「PRナレーション」「完了報告書」の3つのテキスト穴埋め記述を強制し、死者の名前を民俗資料・祈り・事務処理へと能動的に改ざん（加害体験）させる儀式を導入。榊ミトら村人達の「もう忘れさせてほしい」という善意の隠蔽ジレンマを追加。

---

## 2. Godot GUI & Script Updates
*   **Scene File**: [main.tscn](file:///C:/Users/zeros/.gemini/antigravity/scratch/project_manuals/godot_starter/scenes/main.tscn)
    - Added the `ScenarioEp3Button` to the sidebar directly beneath the Episode 1 button.
*   **Script**: [main.gd](file:///C:/Users/zeros/.gemini/antigravity/scratch/project_manuals/godot_starter/scripts/main.gd)
    - Registered "シナリオ EP3" inside the `DOCUMENTS` array to automatically map the scene button, parse headings into the TOC sidebar, and read the relative markdown files on click.
    - Updated `_on_save_pressed()` and `_on_load_pressed()` to use `"user://session_log.json"`.
    - Updated `_on_export_pressed()` to write the Markdown output to `"user://session_log.md"`, in addition to copying it to the system clipboard.

---

## 3. Verification Expansion
*   **Smoke Test**: [viewer_smoke_test.gd](file:///C:/Users/zeros/.gemini/antigravity/scratch/project_manuals/godot_starter/tests/viewer_smoke_test.gd)
    - Expanded reference bindings to check for `ScenarioEp3Button`.
    - Added a click test on `ScenarioEp3Button` to assert that the TOC parses and updates headings dynamically for the new scenario.
    - Expanded search smoke terms to include `"帳外帳"` to verify search normalized alias logic inside Episode 3's context.
    - Added comprehensive validation for Save/Load and Exporter operations:
      - Clears old files from the user directory.
      - Sets state and creates a test card, then triggers Save to verify `user://session_log.json` is successfully created.
      - Mutates credibility and clears cards, then triggers Load to verify the exact state is restored.
      - Triggers Export to verify `user://session_log.md` is created with correct contents (title, test card title, and description).
