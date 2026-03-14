# REPO Split Runbook (PowerShell)

> Bash 依存を外し、PowerShell だけで「既存リポからサブツリーを切り出して新リポに持っていく」手順です。**まだ push は実行しません。**

## 0. 事前準備
- PowerShell 7 以上
- Git がインストール済み
- 分割したいサブディレクトリ名と新リポの URL を決めておく

```powershell
# 必須変数（自分の環境に合わせて書き換え）
$env:SOURCE_ROOT   = "C:\work\monolith"          # 元リポのルート
$env:SUBDIR        = "services\api"              # 切り出すサブディレクトリ
$env:TARGET_ROOT   = "C:\work\api-split"         # 作業先（空ディレクトリを推奨）
$env:NEW_REPO_URL  = "git@github.com:org/api.git" # まだ push しないのでダミーでも可
```

## 1. 安全確認
```powershell
if (-not (Test-Path $env:SOURCE_ROOT)) { throw "SOURCE_ROOT not found: $env:SOURCE_ROOT" }
if (-not (Test-Path (Join-Path $env:SOURCE_ROOT ".git"))) { throw "SOURCE_ROOT is not a git repo" }
if (Test-Path $env:TARGET_ROOT) { throw "TARGET_ROOT already exists. Choose an empty path." }
```

## 2. サブディレクトリをコピー（Bash 不要）
```powershell
Copy-Item `
  -Path    (Join-Path $env:SOURCE_ROOT $env:SUBDIR) `
  -Destination $env:TARGET_ROOT `
  -Recurse -Force
```

任意で README などを追記する場合は here-string を使います:
```powershell
@"
# API Service (split from monolith)
Source: $($env:SOURCE_ROOT)\$($env:SUBDIR)
Split Date: $(Get-Date -Format "yyyy-MM-dd")
"@ | Out-File -FilePath (Join-Path $env:TARGET_ROOT "README.md") -Encoding utf8
```

## 3. Git を初期化（履歴を持たないシンプル版）
```powershell
Set-Location $env:TARGET_ROOT
git init -b main
git add .
git commit -m "Initial import from $env:SUBDIR"

# リモートは設定だけ（push はまだしない）
git remote add origin $env:NEW_REPO_URL
```

## 4. 追加の整理（例: 不要物の削除 / 移動）
```powershell
# 例: 不要な実行ファイルを削除
$artifacts = @("*.pyc", "dist", "node_modules")
foreach ($pattern in $artifacts) {
    Get-ChildItem -Path . -Recurse -Filter $pattern | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# 例: ドキュメントを docs/ にまとめる
if (-not (Test-Path "docs")) { New-Item -ItemType Directory -Path "docs" | Out-Null }
foreach ($file in @("README.md", "CHANGELOG.md")) {
    if (Test-Path $file) { Move-Item $file "docs" -Force }
}
```

## 5. (オプション) 最短コピペ版
最短で動かしたい場合は、次の 4 行だけをコピペして書き換えます:
```powershell
$env:SOURCE_ROOT="C:\work\monolith"; $env:SUBDIR="services\api"; $env:TARGET_ROOT="C:\work\api-split"; $env:NEW_REPO_URL="git@github.com:org/api.git"
Copy-Item (Join-Path $env:SOURCE_ROOT $env:SUBDIR) $env:TARGET_ROOT -Recurse
Set-Location $env:TARGET_ROOT; git init -b main; git add .; git commit -m "Initial import"; git remote add origin $env:NEW_REPO_URL
# push したいときだけ: git push -u origin main
```

---
- ここまでで **push は実行していません**。リモートに送る前にコードオーナー確認やライセンス確認を行ってください。
- 元リポの履歴を保持したい場合は `git filter-repo` などを追加で実行してください（この runbook では扱いません）。
