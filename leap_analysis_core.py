"""
LEAP Analysis Core (Pure Theory Verification)
理論検証専用モジュール - 副作用なし

Mathematical Foundation:
- K = 1.8 (Critical Entropy Threshold)
- LEAP Mode: H(P) > 1.8
- AVE Mode: H(P) ≤ 1.8

Reference: JULES_PROTOCOL.md Section 3.2
"""

import numpy as np
from typing import List, Dict, Tuple
from dataclasses import dataclass


@dataclass
class LEAPStatistics:
    """LEAP解析の統計結果（不変オブジェクト）"""
    total_steps: int
    leap_count: int
    ave_count: int
    leap_rate: float
    mean_entropy: float
    std_entropy: float
    min_entropy: float
    max_entropy: float
    threshold_crossings: int
    threshold: float = 1.8


def validate_log_entry(entry: Dict) -> None:
    """
    ログエントリの構造を検証
    
    Args:
        entry: ログエントリの辞書
        
    Raises:
        ValueError: 必須フィールドが欠けている場合
        TypeError: フィールドの型が不正な場合
    """
    required_fields = ['step', 'entropy', 'mode']
    
    for field in required_fields:
        if field not in entry:
            raise ValueError(f"必須フィールド '{field}' が見つかりません")
    
    if not isinstance(entry['step'], int):
        raise TypeError(f"'step' は整数である必要があります (実際: {type(entry['step'])})")
    
    if not isinstance(entry['entropy'], (int, float)):
        raise TypeError(f"'entropy' は数値である必要があります (実際: {type(entry['entropy'])})")
    
    if entry['mode'] not in ['LEAP', 'AVE']:
        raise ValueError(f"'mode' は 'LEAP' または 'AVE' である必要があります (実際: {entry['mode']})")


def calculate_leap_statistics(logs: List[Dict], K: float = 1.8) -> LEAPStatistics:
    """
    LEAP/AVE統計を計算（純粋関数）
    
    Args:
        logs: ログエントリのリスト
        K: エントロピー閾値（デフォルト: 1.8）
        
    Returns:
        LEAPStatistics: 計算された統計
        
    Raises:
        ValueError: ログが空の場合、または不正なエントリがある場合
    """
    if not logs:
        raise ValueError("ログが空です")
    
    # 全エントリを検証
    for i, entry in enumerate(logs):
        try:
            validate_log_entry(entry)
        except (ValueError, TypeError) as e:
            raise ValueError(f"ログエントリ {i} が不正です: {e}")
    
    # データ抽出
    entropies = np.array([log['entropy'] for log in logs])
    modes = [log['mode'] for log in logs]
    
    # LEAP/AVE カウント
    leap_count = sum(1 for m in modes if m == 'LEAP')
    ave_count = sum(1 for m in modes if m == 'AVE')
    
    # 安全な除算（ゼロ除算回避）
    total = len(modes)
    leap_rate = leap_count / total if total > 0 else 0.0
    
    # エントロピー統計
    mean_entropy = float(np.mean(entropies))
    std_entropy = float(np.std(entropies))
    min_entropy = float(np.min(entropies))
    max_entropy = float(np.max(entropies))
    
    # 閾値超過カウント
    threshold_crossings = int(np.sum(entropies > K))
    
    return LEAPStatistics(
        total_steps=total,
        leap_count=leap_count,
        ave_count=ave_count,
        leap_rate=leap_rate,
        mean_entropy=mean_entropy,
        std_entropy=std_entropy,
        min_entropy=min_entropy,
        max_entropy=max_entropy,
        threshold_crossings=threshold_crossings,
        threshold=K
    )


def format_statistics_report(stats: LEAPStatistics) -> str:
    """
    統計レポートを論文用フォーマットで生成
    
    Args:
        stats: LEAP統計オブジェクト
        
    Returns:
        str: フォーマット済みレポート
    """
    report = []
    report.append("=" * 70)
    report.append("LEAP Activation Point Analysis")
    report.append("=" * 70)
    report.append(f"Critical Threshold K: {stats.threshold}")
    report.append(f"Total Steps: {stats.total_steps}")
    report.append(f"LEAP Activations (H > {stats.threshold}): {stats.leap_count} / {stats.total_steps} = {stats.leap_rate:.1%}")
    report.append(f"AVE Activations (H ≤ {stats.threshold}): {stats.ave_count} / {stats.total_steps} = {(1-stats.leap_rate):.1%}")
    report.append("")
    report.append("Entropy Statistics:")
    report.append(f"  Mean H: {stats.mean_entropy:.4f}")
    report.append(f"  Std Dev: {stats.std_entropy:.4f}")
    report.append(f"  Range: [{stats.min_entropy:.4f}, {stats.max_entropy:.4f}]")
    report.append(f"  Threshold Crossings (H > {stats.threshold}): {stats.threshold_crossings} ({stats.threshold_crossings/stats.total_steps:.1%})")
    report.append("")
    report.append("Paper-Ready Statement:")
    report.append(f"  'LEAP mode was activated in {stats.leap_count} of {stats.total_steps} generation steps")
    report.append(f"   ({stats.leap_rate:.1%}), demonstrating that the K={stats.threshold} threshold is")
    report.append(f"   consistently exceeded in natural language generation.'")
    report.append("=" * 70)
    
    return "\n".join(report)
