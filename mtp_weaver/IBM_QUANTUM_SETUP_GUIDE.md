# IBM Quantum Platform: 操作手順ガイド (T-IAT Bridge Edition)

IBM Quantum の 10分間 (600秒) という貴重なリソースを、Weaver の不変量証明に活用するための具体的な手順です。

---

## ステップ 1: API トークンの取得

まず、プログラムから IBM の量子コンピュータに指令を送るための「鍵」を取得します。

1. **[IBM Quantum Platform](https://quantum.ibm.com/)** にログインします。
2. ダッシュボード右上の **「Copy API Token」** をクリックします。
3. コピーした文字列を、メモ帳などに大切に保管してください。

---

## ステップ 2: ローカル環境の準備 (Python)

あなたのノートパソコン (16GB) 上で、量子回路を組み立てるためのライブラリをインストールします。

```powershell
pip install qiskit qiskit-ibm-runtime
```

---

## ステップ 3: アカウントの認証

取得した API トークンを使って、あなたの PC と IBM を接続します。一度実行すれば保存されます。

```python
from qiskit_ibm_runtime import QiskitRuntimeService

# トークンをここに貼り付けて一度だけ実行します
QiskitRuntimeService.save_account(channel="ibm_quantum", token="YOUR_API_TOKEN_HERE", overwrite=True)
```

---

## ステップ 4: 理論上の「編み込み」を量子回路へ送る

Weaver が生成した「不変量検証コード」を実行する際の典型的な流れです。

1. **回路の構築**: 私 (Weaver) が作成した Python コードを実行します。
2. **実行 (Job Submit)**: 最も空いている実機 (Least Busy Backend) を自動で選択し、キュー（行列）に並びます。
3. **結果の受信**: 実行が終わると、データの「確率分布」が返ってきます。

---

## 【重要】10分間を無駄にしないための Weaver の役割

- **事前シミュレーション**: Jules (またはローカル PC) で事前に 100% 成功することを確認してから、IBM の実機に送ります。
- **バッチ処理**: 各計算を個別に送るのではなく、複数の検証を一つの「ジョブ」にまとめて送り、オーバーヘッドを最小化します。

---
*TEAM CODE: MIRROR_HEART | STATUS: QUANTUM_READY*
