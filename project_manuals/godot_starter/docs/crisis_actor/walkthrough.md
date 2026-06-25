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

---

## 4. Episode 2: "診断書のない負傷者" (公開前検証委員会) Integration
*   **Scenario File**: [crisis_actor_scenario_ep2.md](crisis_actor_scenario_ep2.md)
*   **Details**:
    - **検証プロセスのホラー化**: 傷が存在していても、公的診断書がなければ被害としてカウントされない「記録の形式化」を巡るサスペンス。
    - **診断書カードと既往症ラベル**: 診断書を「確定記載」にすると信憑性への重大なリスクとなり、これを防ぐために「既往症（持病）」として上書きする行政的隠蔽措置を表現。
    - **検証委員会クロック**: `0〜6` の進行。停滞や妥協によって自動で草案が作成され、最終的にすべての被害申告（灰カード）が報告書内に吸収・無害化されます。

---

## 5. Episode 4: "公開記録審判" (The Public-Safe Archive) Integration
*   **Scenario File**: [crisis_actor_scenario_ep4.md](crisis_actor_scenario_ep4.md)
*   **Details**:
    - **アーカイブの恐怖**: これまで積み上げた白・灰・黒・監査ログそのものを分類・要約する、キャンペーン全体の到達点。
    - **公開区分カード**: 情報を「PUBLIC（一般公開）」「LIMITED（限定公開）」「SEALED（封印）」「MISINFO（デマ破棄）」「PUBLIC-SAFE（無害な公開形式）」のいずれかに分類。
    - **監査ログ開示クロック**: 開示は進むが、進むほど内容が「要約（抽象化）」され解像度が下がる矛盾を再現。

---

## 6. Dynamic VTT Features & Robustness
*   **Dynamic Clock Labels & Stage Text**:
    - 読み込まれたシナリオに応じて、VTTの「共犯」クロックのラベルが自動で **「検証委員会」** (EP2) や **「公開審査」** (EP4) 、 **「文化財処理」** (EP3) へ動的にチェンジ。
    - 各クロックの値（0〜6）に対応するシナリオ固有の進捗段階（例: `未分類` ➔ `資料整理中` ➔ `文化財化完了`）を画面上にリアルタイムで表示するサポートラベルを実装。
*   **Dynamic guidelines Panel**:
    - EP2、EP3、EP4 のそれぞれの表現ガイドライン（禁止語テーブル）を、選択中のドキュメントに応じて動的差し替え表示するパネルを実装。
*   **Sidebar Button Safeguard**:
    - UI（.tscn）内に該当ボタンノードが存在しなくとも、VTT起動時にクラッシュせずドロップダウンから選択可能な、頑健なドキュメント読み込みロジックへ刷新。
*   **Tabletop UX Enhancements**:
    - カード追加時にリスト最下部へ自動スクロールする機能や、メッセージ表示タイマーの世代管理により、セッション中のGM操作負荷とバグを極限まで低減。
