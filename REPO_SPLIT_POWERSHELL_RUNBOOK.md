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

## 6. プロジェクト別の変数例
```
# cognitive-lab を切り出す例
$env:SUBDIR="cognitive-lab";     $env:NEW_REPO_URL="git@github.com:org/cognitive-lab.git"

# ea-aol を切り出す例
$env:SUBDIR="ea-aol";            $env:NEW_REPO_URL="git@github.com:org/ea-aol.git"

# mtp-weaver を切り出す例
$env:SUBDIR="mtp_weaver";        $env:NEW_REPO_URL="git@github.com:org/mtp-weaver.git"

# lab-experiments を切り出す例
$env:SUBDIR="lab-experiments";   $env:NEW_REPO_URL="git@github.com:org/lab-experiments.git"
```

## 7. 履歴を残したい場合 (git filter-repo)
> 事前に `pip install git-filter-repo` などでツールを準備してください。
>
> **重要**: `git filter-repo` は履歴をその場で書き換えます。必ず **元リポのフレッシュクローン（またはバックアップ）** に対して実行してください。作業中の clone で実行すると元リポを破壊する恐れがあります。
```powershell
# 1. 元リポをフレッシュクローンして作業用コピーを作成する
git clone $env:SOURCE_ROOT $env:TARGET_ROOT

# 2. 指定サブディレクトリだけに履歴を絞り込む（元リポには影響しない）
Set-Location $env:TARGET_ROOT
git filter-repo --path $env:SUBDIR --path-rename "${env:SUBDIR}/:" --force

# 3. 新しいリモートを設定する（push はまだしない）
git remote add origin $env:NEW_REPO_URL
# push するなら: git push -u origin main
```

## 8. scratch をアーカイブする場合
```powershell
Set-Location $env:SOURCE_ROOT
if (-not (Test-Path "archive")) { New-Item -ItemType Directory -Path "archive" | Out-Null }
Compress-Archive -Path "." -DestinationPath ".\archive\scratch-$(Get-Date -Format 'yyyyMMdd').zip"
```

- ここまでで **push は実行していません**。リモートに送る前にコードオーナー確認やライセンス確認を行ってください。
- 履歴を保持したい場合はセクション 7 の `git filter-repo` 手順を使ってください。
- PowerShell での実行を前提としています。Bash は不要です。
