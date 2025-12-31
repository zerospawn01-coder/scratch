# Geodesic Descent - 学習記録（プロジェクト終了）

**Status:** ❌ TERMINATED  
**Date:** 2025-12-15  
**Reason:** 先行研究（K-FAC, Shampoo）により新規性なし  

---

## プロジェクト概要

**仮説:**
> "ニューラルネットワークの学習軌道は、高次元空間にもかかわらず、実質的に1次元の測地線上を移動する"

**発見:**
- シミュレーション: PC1/PC2 = 17.5x
- 実データ（MNIST）: PC1/PC2 = 30.15x
- 実装: BulletTrainSGD optimizer
- ベンチマーク: 2.70x speedup（報告値）

**結論:**
- ✅ 技術的には成功（2.7x高速化）
- ❌ 商業的には失敗（先行研究が存在）

---

## 先行研究

### K-FAC (2015)
- **著者:** James Martens & Roger Grosse
- **手法:** Fisher情報行列のKronecker因数分解
- **結果:** 2-3x speedup

### Shampoo (2018)
- **著者:** Vineet Gupta et al.
- **手法:** Kronecker前処理による二次最適化
- **結果:** 2-3x speedup

### SOAP (2024)
- **手法:** Shampoo + Adam の融合
- **結果:** さらなる効率化

**結論:** BulletTrainSGDは独立再発見（Independent Rediscovery）

---

## 学んだ教訓

### 1. 文献調査は最優先
- 実装前に既存手法を徹底調査すべき
- 「二次最適化」「低ランク」で検索すれば即座に発見できた

### 2. 用語の罠
- 独自用語（"Stiff-Sloppy"）を使用
- 既存用語（"Fisher情報行列"）と結びつかなかった

### 3. 独立再発見の価値
- **学習には有益:** 理論を独力で再構築、実装スキル向上
- **ビジネスには無価値:** 商業的価値ゼロ、時間の浪費

---

## プロジェクトタイムライン

- **Day 1:** 仮説構築（1次元測地線）
- **Day 2:** 発見（PC1/PC2 = 30.15x）
- **Day 3:** 実装（BulletTrainSGD）
- **Day 4:** 検証（2.7x speedup報告）
- **Day 5:** 終了（先行研究発見）

---

## 技術的成果（学習記録として）

### 実装したもの
- PCAベースの勾配分解
- Lazy PC1 estimation（50ステップごと）
- 異方性更新（Stiff/Sloppy分離）
- ベンチマークフレームワーク

### 習得したスキル
- PyTorch optimizer実装
- PCA/固有値解析
- 二次最適化の理論
- ベンチマーク設計

---

## 詳細分析

詳細な先行研究分析は `PRIOR_ART_ANALYSIS.md` を参照してください。

---

## 次のステップ

このプロジェクトは終了しました。

**次の優先事項:**
1. 「1.8の法則」プロジェクトに戻る
2. 文献調査を徹底する
3. 新しい仮説を探索する

---

**教訓:** "Always check prior art BEFORE implementation."

**記録日:** 2025-12-15
