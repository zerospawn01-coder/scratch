# Godot 4 HD-2D プロトタイプ構築ガイド
## 「The Biosynthesized Grey Zone Loop」完全実装テンプレート

本書は、3D空間に2Dドット絵キャラクターを配置するHD-2Dスタイルで、『The Biosynthesized Grey Zone Loop』の探索フィールド、第4設備での「バイオロイド合成の培養演出」、および「アリーナ模擬戦闘」を構築するためのGodot 4（GDScript）向け実践ガイド＆実装セットアップです。

---

### 📂 プロジェクト構造一覧

```text
res://
├── project.godot                     # Godot 4 プロジェクト設定（入力マップ設定済み）
├── shaders/
│   └── cultivation_fluid.gdshader   # 第4設備「培養液」発光・浮遊シェーダー
├── scripts/
│   ├── investigator.gd               # 調査員移動＆スプライト反転スクリプト
│   ├── follow_camera.gd              # 斜め見下ろしスムーズ追従＆シェイク機能付きカメラ
│   ├── investigator_fsm.gd           # 状態遷移（待機・移動・攻撃・合成・被弾）FSM
│   ├── bioroid_synthesis_pod.gd      # 培養槽エフェクト・シーケンス制御
│   └── arena_battle_manager.gd       # アリーナ戦術戦闘・エーテルゲージ・ヒットストップ
└── scenes/
    ├── exploration_scene.tscn        # 探索メインシーン（環境・調査員・カメラ）
    └── arena_battle_scene.tscn       # 模擬戦闘シーン
```

---

### 1. 最小サンプルプロジェクト：シーンとスクリプト

#### 1-1. ノード構成 (エディタ上での配置)
メインの探索シーン（`exploration_scene.tscn`）を以下の構成で作成します。

```text
ExplorationScene (Node3D)
├── WorldEnvironment (WorldEnvironment)       # HD-2Dトーンマップ・SSAO・フォグ設定
├── DirectionalLight3D (DirectionalLight3D)    # 太陽光 / 影(Shadow)をEnabled
├── GridMap or StaticBody3D (StaticBody3D)     # 3D床・壁
│   ├── MeshInstance3D                         # 平面プレーン
│   └── CollisionShape3D                      # 衝突判定
├── Investigator (CharacterBody3D)             # 調査員（プレイヤー）
│   ├── AnimatedSprite3D (AnimatedSprite3D)   # Y-Billboard & Nearestフィルター設定
│   ├── CollisionShape3D (CollisionShape3D)   # カプセル型コライダー
│   └── (Script: investigator_fsm.gd)         # プレイヤー制御FSM
├── CultivationPod04 (Node3D)                  # 第4設備培養槽
│   ├── MeshInstance3D (培養液ガラス筒)       # Material: cultivation_fluid.gdshader
│   ├── GPUParticles3D (泡パーティクル)
│   └── (Script: bioroid_synthesis_pod.gd)    # 培養シーケンス
└── MainCamera (Camera3D)                      # 追従カメラ
    └── (Script: follow_camera.gd)            # ターゲット追従スクリプト
```

---

### 2. HD-2D風 WorldEnvironment & 質感設定

#### 2-1. AnimatedSprite3Dの設定（ドット絵をぼかさない）
ドット絵スプライトが3D空間でボケるのを防ぎ、3Dの影を投影するための必須設定です。

1. **AnimatedSprite3D** ノードを選択します。
2. **Flags** グループを展開：
   - `Texture Filter`: **Nearest** （ピクセルをくっきり表現）
   - `Billboard`: **Y-Billboard** （直立したままカメラに向く）
3. **Geometry** グループを展開：
   - `Cast Shadow`: **On** （2Dドット絵のシルエット影を3D地面に投影）
   - `Transparent`: **On**
   - `Alpha Cut`: **Discard** または **Opaque Pre-Pass** （影の輪郭をきれいに透過カット）

#### 2-2. 「グレーゾーン」を演出する環境設定
- **Ambient Light**: Color `#141f2b` (冷たいダークトーン), Energy `0.4`
- **Tonemap**: Mode **Filmic** または **ACES** (映画的色調)
- **SSAO**: Enabled (建物の隅にリアルな陰影を落とす)
- **Volumetric Fog**: Enabled, Color `#1a2420`, Density `0.03` (光条ゴッドレイを表現)

---

### 3. アニメーション切り替え＆状態遷移 (FSM)

[investigator_fsm.gd](file:///C:/Users/zeros/.gemini/antigravity-ide/scratch/biosynthesized-grey-zone-loop/scripts/investigator_fsm.gd) スクリプトにより以下の状態を透過管理します。
- `IDLE`: 方向に応じた待機 (`idle_down`, `idle_up`, `idle_side`)
- `MOVE`: 入力方向に応じた歩行 (`walk_down`, `walk_up`, `walk_side`) ＋ 右向きアニメーションの自動 `flip_h` 反転
- `ATTACK`: Zキー/攻撃ボタンでのスラッシュアクション
- `SYNTHESIS`: Xキーでの培養槽インターフェース接続中（移動ロック）

---

### 4. 第4設備「バイオロイド合成の培養演出」

[bioroid_synthesis_pod.gd](file:///C:/Users/zeros/.gemini/antigravity-ide/scratch/biosynthesized-grey-zone-loop/scripts/bioroid_synthesis_pod.gd) および [cultivation_fluid.gdshader](file:///C:/Users/zeros/.gemini/antigravity-ide/scratch/biosynthesized-grey-zone-loop/shaders/cultivation_fluid.gdshader) で表現：
- シーケンス進行に伴い、培養液のうねり速度 (`pulse_speed`) と光の歪み (`distortion_strength`) が高まり、気泡パーティクルが激化。
- 合成完了時にバイオロイド固有の遺伝子パラメータ（`ether_affinity` 等）を発行。

---

### 5. アリーナ模擬戦闘ロジック

[arena_battle_manager.gd](file:///C:/Users/zeros/.gemini/antigravity-ide/scratch/biosynthesized-grey-zone-loop/scripts/arena_battle_manager.gd) による戦術戦闘制御：
- **エーテルドライブ**: 基本技でエーテルゲージを溜め、強技 `GENE_BURST` を発動。
- **ヒットストップ**: クリティカルヒット時に `Engine.time_scale` を一瞬落とし、強い打撃感を生む。
- **カメラシェイク**: 打撃の瞬間に [follow_camera.gd](file:///C:/Users/zeros/.gemini/antigravity-ide/scratch/biosynthesized-grey-zone-loop/scripts/follow_camera.gd) の `add_shake()` をコールバック。

---

### 🚀 開始手順

1. Godot 4 エディタを開き、上記プロジェクトディレクトリ `biosynthesized-grey-zone-loop` を「読み込み / Import」します。
2. スクリプト類はすべて登録済みですので、ノードにアタッチするだけで即座動作テストが可能です。
