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
    - カード追加時にリスト最下部へ自動スクロールする機能や、メッセージ表示タイマー of `main.gd` の世代管理により、セッション中のGM操作負荷とバグを極限まで低減。

---

## 7. GUI動作確認・レイアウト崩れ対策 (P1修正)
*   **ビジュアル検証自動スクリプト作成**: [visual_check.gd](../../tests/visual_check.gd) を作成し、GodotのGUIを実際に起動して操作をエミュレートし、スクリーンショットを自動生成して外観・操作感を検証しました。
*   **スクリーンショットによる動作証明**:
    1. **初期状態（ルールブック）**: [visual_check_01_init.png](file:///C:/Users/zeros/.gemini/antigravity-ide/brain/4bfddfe1-b698-4fd8-a7ef-6f171e979f52/visual_check_01_init.png)
       - 目次の階層構造、セッション操作用の基本クロックやカード操作ボタンが綺麗に配置されていることを確認。
    2. **EP2選択・ガイドライン展開・クロック進行**: [visual_check_02_ep2_guidelines.png](file:///C:/Users/zeros/.gemini/antigravity-ide/brain/4bfddfe1-b698-4fd8-a7ef-6f171e979f52/visual_check_02_ep2_guidelines.png)
       - コプリミティクロックが「検証委員会：1」になり、「進捗: 資料提出依頼」が表示されていること、またEP2固有の禁止語・推奨代替語テーブルが正しくレンダリングされていることを確認。
    3. **EP4選択・初期状態**: [visual_check_03_ep4_init.png](file:///C:/Users/zeros/.gemini/antigravity-ide/brain/4bfddfe1-b698-4fd8-a7ef-6f171e979f52/visual_check_03_ep4_init.png)
       - シナリオ「公開記録審判」のタイトルへの切り替え、クロックが「公開審査」へ動的変更されたことを確認。
    4. **EP4クロック最大**: [visual_check_04_ep4_clock_max.png](file:///C:/Users/zeros/.gemini/antigravity-ide/brain/4bfddfe1-b698-4fd8-a7ef-6f171e979f52/visual_check_04_ep4_clock_max.png)
       - クロックを6まで進めた際、進捗表示が「要約版のみ公開」になり、且つ「共犯クロック警告」の赤字警告テキストが表示されていることを確認。
    5. **カード追加フォーム表示**: [visual_check_05_card_form.png](file:///C:/Users/zeros/.gemini/antigravity-ide/brain/4bfddfe1-b698-4fd8-a7ef-6f171e979f52/visual_check_05_card_form.png)
       - 白カード追加時にフォームがオーバーレイ表示され、入力項目が正しく表示されることを確認。
    6. **カード追加・カードリスト描画**: [visual_check_06_card_added.png](file:///C:/Users/zeros/.gemini/antigravity-ide/brain/4bfddfe1-b698-4fd8-a7ef-6f171e979f52/visual_check_06_card_added.png)
       - 追加した「テスト公開審判カード」が、左側のカードリストの中に白枠（左ボーダー色）のカードとして正しく描画されることを確認。
    7. **キーワード検索ハイライト**: [visual_check_07_search_highlight.png](file:///C:/Users/zeros/.gemini/antigravity-ide/brain/4bfddfe1-b698-4fd8-a7ef-6f171e979f52/visual_check_07_search_highlight.png)
       - 「広報庁」で検索した際、本文の該当テキストが瞬時にオレンジ色でハイライトされ、検索バーに「1 / 7 件ヒット」と正しく表示されることを確認。
*   **P1修正：カードリスト虚脱（スクロール領域消失）バグの解決**:
    - 実機での動作確認中、クロック、進捗ラベル、警告文、表現調整ガイドラインパネルが動的に追加された際、縦方向のスペースが圧縮されてカードリスト用スクロール領域（`CardScroll`）が縦幅0に潰れてしまい、追加したカードが表示されなくなる重大な不具合を発見。
    - `main.tscn` において、`CardScroll` に `custom_minimum_size = Vector2(0, 150)` を追加指定しました。これにより、縦方向の領域が圧迫された状態でもカードリストが最小限の高さ（150px）を常に保証し、カードが正しく画面にスクロール表示されるようになりました。

---

## 8. P0ルールカーネルと「未処理負債」カウンターの実装
*   **ルールブックの改定**: [crisis_actor_rulebook.md](crisis_actor_rulebook.md)
    - 冒頭に実在の事件や陰謀論との混同を防ぐための **トーン管理文（安全線）** を追加。
    - セッション終了条件と **3軸評価（Public / Audit / Human Outcomes）** によるマルチエンディング評価システムを明文化。
    - 嘘や妥協の代償を表すGM用隠しパラメータ **「未処理負債 (Structural Debt)」** の増減ルールと、圧力帯域（安定 / 圧力 / 破綻前 / 破綻 / 強制クライマックス）ごとの環境変化を定義。
    - **1D6 異常混入イベント表**、カードの公開範囲、倫理監査役（オーディター）の機械的権限（*Witness Claim*, *Black Seal*, *Objection Round*）、黒塗り合議ルールと5分停滞時の解決手順、次回セッションへのパラメータおよびカード持ち越しルールを追記。
*   **VTTデータモデルの強化**: [session_state.gd](../../scripts/session_state.gd)
    - `unprocessed_debt`（未処理負債）パラメータ（0〜10）を実装。
    - undo/redo 履歴、JSONセーブ／ロード、Markdownエクスポート機能に `unprocessed_debt` のシリアライズを追加。
    - `get_warnings()` を拡張し、未処理負債の圧力帯域（3以上）に応じて動的警告テキストを自動出力するシステムを実装。
*   **VTT UIへの統合**: [main.gd](../../scripts/main.gd)
    - 操作パネル (`OpsPanel`) の `ClocksGrid` 内に、未処理負債用のコントロール（ラベル、増減ボタン、値表示）を起動時に動的生成・追加。
    - 値の変更に連動してセッション状態と同期し、警告テキストがリアルタイムで更新されるように接続。
    - クイック検索ワードに `"未処理負債"`, `"構造負債"` を追加。
*   **スモークテストでの検証保証**: [viewer_smoke_test.gd](../../tests/viewer_smoke_test.gd)
    - 未処理負債カウンターの増減および undo/redo、警告閾値の到達による警告テキストの切り替え、Markdownエクスポートでの出力をカバーするテストアサーションを追加し、`VIEWER_SMOKE_PASS` を達成しました。
*   **実機スクリーンショットでの確認**:
    - [visual_check_04_ep4_clock_max.png](file:///C:/Users/zeros/.gemini/antigravity-ide/brain/4bfddfe1-b698-4fd8-a7ef-6f171e979f52/visual_check_04_ep4_clock_max.png) において、「未処理負債」が 3 の時に `⚠️【未処理負債: 圧力】` の警告文が正常に赤字で描画されている様子を確認できます。

---

## 9. P0 Safety & Debrief Kernel（プレイヤー保護・卓外安全）の統合
*   **ルールブックの改定**: [crisis_actor_rulebook.md](crisis_actor_rulebook.md)
    - **P0 Safety & Debrief Kernel の新設**: 
      - **風刺対象の明示**: 実在事件・災害・被害者を題材にしない架空の風刺概念であることを明確化。
      - **Audit Pause（安全一時停止）**: オーディターPLが精神的負荷を感じた際、セッション中2回までゲーム時間を止めて卓外相談できるルールを追加。
      - **卓外安全とゲーム内圧力の分離**: Audit PauseやXカード等の安全確認中、ゲーム内の処理クロックや未処理負債は一切進行しないことを明文化。
      - **Fiction Close の儀式**: セッション終了時に、陰謀論が架空のものであることを確認し、精神的負荷やNG描写を振り返る切断儀式を導入。
      - **Debrief 3問の必須化**: ゲーム内の共犯関係を卓外に持ち越さないためのデブリーフィング（心理的負荷、次回NG要素、精神状態の確認）を定義。
      - **役職ローテーション**: オーディターの心理的負担の集中を避けるため、原則2セッションごとの交代提案をキャンペーンルールに追加。
    - **Emergency Injunction（緊急差止命令）の強化**: 
      - オーディターが1セッション1回使用できる権限として再設計。
      - 対象の隠蔽処理を一時停止し、未処理負債を-1し、対象カードを「保全中」にして次のフェーズでの議題化を強制する効果へアップグレード。
    - **支配的白カードと整合性クロックの追加**:
      - 過去の白カード（嘘）の累積によるGMの管理負荷を減らすため、セッション開始時に3枚まで前提となるカードを選択する「支配的白カード」ルールを実装。
      - 「白カード整合性クロック（0〜6）」を導入し、キャンペーン終盤での公式ナラティブの崩壊プロセスをクライマックス装置として機能させるよう定義。

---

## 10. 各カード種のVTT実装
*   **基本4カード**:
    - `白カード`: 公式ログとして固定された公開事実。
    - `灰カード`: 未処理の矛盾。腐爛段階を保持し、放置や処理判断の対象になる。
    - `黒カード`: 裏ログとして封印された真実。証拠、露出コスト、対立する白カードを記録する。
    - `粗い演出カード`: B級処理による責任の所在と将来リスクを記録する。
*   **拡張5カード**:
    - `支配的白カード`: セッション開始時の前提として効く過去の白カード。
    - `調査対象カード`: 白カードで完全抹消できない、保護された未確定事実。
    - `疑惑カード`: SNS・NPC・報道などから発生する世論ノイズ。
    - `保全中カード`: Emergency Injunction によって一時停止・保全されたカード。
    - `公開区分カード`: EP4のアーカイブ分類（PUBLIC / LIMITED / SEALED / MISINFO / PUBLIC-SAFE）を記録するカード。
*   **VTTデータモデルの強化**: [session_state.gd](../../scripts/session_state.gd)
    - 9種類すべてのカードをセッション状態として保持し、undo履歴、JSONセーブ／ロード、Markdownエクスポートに対応。
    - 古いセーブデータや一部キー欠落のJSONを読み込んでも、読込前にカード配列をクリアして前回画面の残留カードが混ざらないようにしました。
*   **VTT UIへの統合**: [main.gd](../../scripts/main.gd)
    - 操作パネルのカード追加エリアに、拡張カード用の追加ボタンを起動時に動的生成。
    - 各カード種ごとにフォーム見出し、入力プレースホルダー、リスト表示ラベル、左ボーダー色を切り替えるようにしました。
*   **検証保証**: [viewer_smoke_test.gd](../../tests/viewer_smoke_test.gd)
    - 9種類すべてのカードを実際に追加し、保存、削除、読込、Markdown書き出しで内容が保持されることを自動検証。
    - [visual_check.gd](../../tests/visual_check.gd) では白カードと調査対象カードの追加を実機描画対象に含め、拡張カードUIのレイアウト崩れを確認できるようにしました。

