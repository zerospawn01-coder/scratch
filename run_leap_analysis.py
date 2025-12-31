"""
LEAP Analysis Runner (I/O & CLI)
実験パイプライン - ファイル入出力とコマンドライン処理

Usage:
    python run_leap_analysis.py --log-path execution_log.txt --output-dir ./results
"""

import json
import argparse
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
from typing import List, Dict

from leap_analysis_core import calculate_leap_statistics, format_statistics_report


def load_execution_log(log_path: Path) -> List[Dict]:
    """
    実行ログを読み込む
    
    Args:
        log_path: ログファイルのパス
        
    Returns:
        List[Dict]: ログエントリのリスト
        
    Raises:
        FileNotFoundError: ファイルが存在しない場合
        ValueError: JSON パースに失敗した場合
    """
    if not log_path.exists():
        raise FileNotFoundError(f"ログファイルが見つかりません: {log_path}")
    
    logs = []
    try:
        with open(log_path, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, start=1):
                try:
                    logs.append(json.loads(line))
                except json.JSONDecodeError as e:
                    raise ValueError(f"ログファイルの {line_num} 行目に無効な JSON があります: {e}")
    except Exception as e:
        raise ValueError(f"ログファイルの読み込み中にエラーが発生しました: {e}")
    
    return logs


def save_statistics_report(stats_text: str, output_path: Path) -> None:
    """統計レポートをファイルに保存"""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(stats_text)
    print(f"統計レポート保存: {output_path}")


def create_entropy_visualization(logs: List[Dict], K: float, output_path: Path) -> None:
    """
    エントロピー分布と軌跡の可視化
    
    Args:
        logs: ログエントリのリスト
        K: エントロピー閾値
        output_path: 出力画像のパス
    """
    steps = [log['step'] for log in logs]
    entropies = [log['entropy'] for log in logs]
    modes = [log['mode'] for log in logs]
    
    mean_entropy = np.mean(entropies)
    
    fig, axes = plt.subplots(2, 1, figsize=(10, 10))
    
    # ヒストグラム
    axes[0].hist(entropies, bins=20, alpha=0.7, edgecolor='black', color='steelblue')
    axes[0].axvline(x=K, color='red', linestyle='--', linewidth=2, label=f'K={K} Threshold')
    axes[0].axvline(x=mean_entropy, color='green', linestyle=':', linewidth=2, label=f'Mean H={mean_entropy:.3f}')
    axes[0].set_xlabel('Entropy H(P)', fontsize=12)
    axes[0].set_ylabel('Frequency', fontsize=12)
    axes[0].set_title(f'Entropy Distribution in LEAP Decoder (K={K})', fontsize=14, fontweight='bold')
    axes[0].legend(fontsize=10)
    axes[0].grid(alpha=0.3)
    
    # 軌跡
    colors = ['red' if m == 'LEAP' else 'blue' for m in modes]
    axes[1].scatter(steps, entropies, c=colors, alpha=0.6, s=50)
    axes[1].axhline(y=K, color='red', linestyle='--', linewidth=2, label=f'K={K} Threshold')
    axes[1].set_xlabel('Generation Step', fontsize=12)
    axes[1].set_ylabel('Entropy H(P)', fontsize=12)
    axes[1].set_title('Entropy Trajectory (Red=LEAP, Blue=AVE)', fontsize=14, fontweight='bold')
    axes[1].legend(fontsize=10)
    axes[1].grid(alpha=0.3)
    
    plt.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"可視化図保存: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description='LEAP/AVE デコーダーの実行ログを解析',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
例:
  python run_leap_analysis.py --log-path execution_log.txt --output-dir ./results
  python run_leap_analysis.py --log-path D:/research/execution_log.txt --output-dir D:/research/results --threshold 1.8
        """
    )
    
    parser.add_argument(
        '--log-path',
        type=Path,
        required=True,
        help='execution_log.txt へのパス'
    )
    
    parser.add_argument(
        '--output-dir',
        type=Path,
        required=True,
        help='出力先ディレクトリ'
    )
    
    parser.add_argument(
        '--threshold',
        type=float,
        default=1.8,
        help='エントロピー閾値 K (デフォルト: 1.8)'
    )
    
    args = parser.parse_args()
    
    try:
        # ログ読み込み
        print(f"ログ読み込み中: {args.log_path}")
        logs = load_execution_log(args.log_path)
        print(f"  {len(logs)} エントリを読み込みました")
        
        # 統計計算（純粋関数）
        print(f"\n統計計算中 (K={args.threshold})...")
        stats = calculate_leap_statistics(logs, K=args.threshold)
        
        # レポート生成
        report = format_statistics_report(stats)
        print("\n" + report)
        
        # 保存
        stats_path = args.output_dir / "leap_statistics.txt"
        save_statistics_report(report, stats_path)
        
        # 可視化
        print("\n可視化生成中...")
        figure_path = args.output_dir / "figure_entropy_analysis.png"
        create_entropy_visualization(logs, args.threshold, figure_path)
        
        print("\n✅ 解析完了")
        
    except FileNotFoundError as e:
        print(f"❌ エラー: {e}")
        return 1
    except ValueError as e:
        print(f"❌ データエラー: {e}")
        return 1
    except Exception as e:
        print(f"❌ 予期しないエラー: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())
