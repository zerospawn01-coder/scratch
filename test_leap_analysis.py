"""
Unit Tests for LEAP Analysis Core
理論検証コードのテストスイート

各テストは数学的根拠に基づいた期待値を検証します。
"""

import unittest
import numpy as np
from leap_analysis_core import (
    validate_log_entry,
    calculate_leap_statistics,
    format_statistics_report,
    LEAPStatistics
)


class TestLogValidation(unittest.TestCase):
    """ログエントリ検証のテスト"""
    
    def test_valid_entry(self):
        """正常なエントリは検証を通過する"""
        entry = {'step': 1, 'entropy': 2.5, 'mode': 'LEAP'}
        validate_log_entry(entry)  # 例外が発生しないことを確認
    
    def test_missing_field(self):
        """必須フィールドが欠けている場合はエラー"""
        entry = {'step': 1, 'entropy': 2.5}  # 'mode' が欠けている
        with self.assertRaises(ValueError):
            validate_log_entry(entry)
    
    def test_invalid_step_type(self):
        """step が整数でない場合はエラー"""
        entry = {'step': '1', 'entropy': 2.5, 'mode': 'LEAP'}
        with self.assertRaises(TypeError):
            validate_log_entry(entry)
    
    def test_invalid_mode_value(self):
        """mode が LEAP/AVE 以外の場合はエラー"""
        entry = {'step': 1, 'entropy': 2.5, 'mode': 'INVALID'}
        with self.assertRaises(ValueError):
            validate_log_entry(entry)


class TestLEAPStatistics(unittest.TestCase):
    """LEAP統計計算のテスト"""
    
    def test_leap_rate_calculation(self):
        """LEAP率の計算が手動カウントと一致する"""
        logs = [
            {'step': 1, 'entropy': 2.0, 'mode': 'LEAP'},
            {'step': 2, 'entropy': 1.5, 'mode': 'AVE'},
            {'step': 3, 'entropy': 2.5, 'mode': 'LEAP'},
            {'step': 4, 'entropy': 1.0, 'mode': 'AVE'},
            {'step': 5, 'entropy': 1.7, 'mode': 'AVE'},
        ]
        
        stats = calculate_leap_statistics(logs, K=1.8)
        
        # 期待値: 2/5 = 40%
        assert stats.leap_count == 2
        assert stats.ave_count == 3
        assert abs(stats.leap_rate - 0.4) < 0.001
    
    def test_threshold_crossing_detection(self):
        """エントロピー閾値超過の検出が正しい"""
        logs = [
            {'step': 1, 'entropy': 1.5, 'mode': 'AVE'},   # < 1.8
            {'step': 2, 'entropy': 2.0, 'mode': 'LEAP'},  # > 1.8
            {'step': 3, 'entropy': 1.7, 'mode': 'AVE'},   # < 1.8
            {'step': 4, 'entropy': 2.5, 'mode': 'LEAP'},  # > 1.8
            {'step': 5, 'entropy': 1.9, 'mode': 'LEAP'},  # > 1.8
        ]
        
        stats = calculate_leap_statistics(logs, K=1.8)
        
        # 期待値: 2.0, 2.5, 1.9 の3つが閾値を超過
        assert stats.threshold_crossings == 3
    
    def test_entropy_statistics(self):
        """エントロピー統計が正しく計算される"""
        logs = [
            {'step': 1, 'entropy': 1.0, 'mode': 'AVE'},
            {'step': 2, 'entropy': 2.0, 'mode': 'LEAP'},
            {'step': 3, 'entropy': 3.0, 'mode': 'LEAP'},
        ]
        
        stats = calculate_leap_statistics(logs, K=1.8)
        
        # 期待値: mean=2.0, min=1.0, max=3.0
        assert abs(stats.mean_entropy - 2.0) < 0.001
        assert abs(stats.min_entropy - 1.0) < 0.001
        assert abs(stats.max_entropy - 3.0) < 0.001
        
        # 標準偏差: sqrt(((1-2)^2 + (2-2)^2 + (3-2)^2) / 3) = sqrt(2/3) ≈ 0.816
        expected_std = np.std([1.0, 2.0, 3.0])
        assert abs(stats.std_entropy - expected_std) < 0.001
    
    def test_empty_logs_raises_error(self):
        """空のログはエラーを発生させる"""
        with self.assertRaises(ValueError):
            calculate_leap_statistics([])
    
    def test_invalid_entry_raises_error(self):
        """不正なエントリはエラーを発生させる"""
        logs = [
            {'step': 1, 'entropy': 2.0, 'mode': 'LEAP'},
            {'step': 2, 'entropy': 1.5},  # 'mode' が欠けている
        ]
        
        with self.assertRaises(ValueError):
            calculate_leap_statistics(logs)
    
    def test_zero_division_safety(self):
        """ゼロ除算が安全に処理される"""
        # 実際には空ログでエラーになるが、内部的にゼロ除算保護がある
        logs = [{'step': 1, 'entropy': 2.0, 'mode': 'LEAP'}]
        stats = calculate_leap_statistics(logs)
        
        # 1個のログでも正常に計算される
        self.assertEqual(stats.total_steps, 1)
        self.assertEqual(stats.leap_rate, 1.0)


class TestReportFormatting(unittest.TestCase):
    """レポートフォーマットのテスト"""
    
    def test_report_contains_key_metrics(self):
        """レポートに主要な統計が含まれる"""
        stats = LEAPStatistics(
            total_steps=100,
            leap_count=60,
            ave_count=40,
            leap_rate=0.6,
            mean_entropy=2.5,
            std_entropy=0.8,
            min_entropy=1.0,
            max_entropy=4.0,
            threshold_crossings=65,
            threshold=1.8
        )
        
        report = format_statistics_report(stats)
        
        # 主要な値が含まれているか確認
        self.assertIn("Total Steps: 100", report)
        self.assertIn("LEAP Activations", report)
        self.assertIn("60.0%", report)
        self.assertIn("Mean H: 2.5000", report)
        self.assertIn("K=1.8", report)


if __name__ == "__main__":
    unittest.main()
