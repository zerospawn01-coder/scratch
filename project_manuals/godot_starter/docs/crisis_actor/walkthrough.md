# CRISIS ACTOR: Tabletop Operation Tool (VTT Minimal) Walkthrough

The Godot-based **CRISIS ACTOR VTT Minimal** tool has been successfully updated to include the new custom scenario, **Episode 3: 帳外神楽 (Chougai-Kagura)**, framing regional folklore as a decentralized audit log, along with comprehensive **Session Save/Load** and **Markdown Export** operations.

---

## 1. Episode 3: "帳外神楽" (v0.3 行政ホラー版) Integration
*   **Scenario File**: [crisis_actor_scenario_ep3.md](crisis_actor_scenario_ep3.md)
*   **Details**:
    - **コンセプトの極大化**: 「祟りや怪異」ではなく、「死者の名前を資料分類・観光資源へと事務的に処理・消去していく行政の無機質な暴力」をホラーの核に据えました。
    - **タイトル二層化**: 第3話「帳外神楽」に、副題「超外神殻」を追加。村の口承ログを、行政文書・文化財分類・観光PR・監査ログが包み込み、告発不能な文化資源へ変換する構造を明示。
    - **文化財化処理クロック**: `0〜6` の進行クロックを追加。未処理カードの放置、民俗文化としての撮影、機材ノイズ処理、県の表現調整受諾、黒塗り理由コード使用などで進行し、6で黒カード化不能になります。
    - **「異物フレーム」カードの追加**: 旧「面の子」のオカルト的描写を廃し、鈴の音の周波数干渉や編集ミス、村人の作為による機材ノイズ（灰カード）に変更し、処理テーブル（機材/編集ミス/仕込み/演出）を追加。
    - **陰謀論配信者ノゾミの再定義**: プレイヤーの推理を奪わないよう、的外れな主張と本物の「一次データ」を併せ持つ「扱いに困る素材散布装置」へ再設計。さらに「結論を3秒以上語らず、一次データを必ず1つ場に出す」運用ルールを追加。
    - **選択肢A（白カード化）での実体験**: プレイヤー自身に「展示解説文」「PRナレーション」「完了報告書」の3つのテキスト穴埋め記述を強制し、死者の名前を民俗資料・祈り・事務処理へと能動的に改ざん（加害体験）させる儀式を導入。禁止語・代替語リスト、黒塗り理由コード、末尾の `[AUDIT LOG: OKR-CULTURAL-ASSET-CONVERSION]` 監査ログを追加。
    - **選択肢B（限定暴露）の強化**: 「調査対象カード」を追加。白カードによる完全無力化も、黒カードとしての即時告発もできない、次回以降へ残る棘として扱います。

---

## 2. Godot GUI & Script Updates
*   **Scene File**: [main.tscn](../../scenes/main.tscn)
    - Added the `ScenarioEp3Button` to the sidebar directly beneath the Episode 1 button.
*   **Script**: [main.gd](../../scripts/main.gd)
    - Registered "シナリオ EP3" inside the `DOCUMENTS` array to automatically map the scene button, parse headings into the TOC sidebar, and read the relative markdown files on click.
    - Added quick-search terms for `"文化財化処理クロック"`, `"黒塗り理由コード"`, and `"調査対象カード"`.
    - Updated `_on_save_pressed()` and `_on_load_pressed()` to use `"user://session_log.json"`.
    - Updated `_on_export_pressed()` to write the Markdown output to `"user://session_log.md"`, in addition to copying it to the system clipboard.

---

## 3. Verification Expansion
*   **Smoke Test**: [viewer_smoke_test.gd](../../tests/viewer_smoke_test.gd)
    - Expanded reference bindings to check for `ScenarioEp3Button`.
    - Added a click test on `ScenarioEp3Button` to assert that the TOC parses and updates headings dynamically for the new scenario.
    - Expanded search smoke terms to include `"帳外帳"`, `"文化財化処理クロック"`, `"黒塗り理由コード"`, and `"調査対象カード"` to verify Episode 3's final scenario terms.
    - Added comprehensive validation for Save/Load and Exporter operations:
      - Clears old files from the user directory.
      - Sets state and creates a test card, then triggers Save to verify `user://session_log.json` is successfully created.
      - Mutates credibility and clears cards, then triggers Load to verify the exact state is restored.
      - Triggers Export to verify `user://session_log.md` is created with correct contents (title, test card title, and description).
