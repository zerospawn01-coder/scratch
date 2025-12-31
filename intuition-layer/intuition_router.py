import time
import torch
import numpy as np
from typing import Tuple, Dict
from transformers import AutoModelForCausalLM, AutoTokenizer, pipeline
from memory_bank import FixedMemoryBank

class IntuitionRouter:
    """推論起動制御レイヤー (Phase A: Transformers Safe Version)"""
    
    def __init__(
        self, 
        model_name: str = "Qwen/Qwen2.5-0.5B-Instruct",
        memory_size: int = 1000,
        tau1: float = 0.6,
        tau2: float = 1.2,
        theta1: float = 0.5,
        theta2: float = 0.6
    ):
        print(f"Loading model {model_name} in resource-safe mode...")
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.model = AutoModelForCausalLM.from_pretrained(
            model_name,
            torch_dtype=torch.float16 if self.device == "cuda" else torch.float32,
            device_map="auto"
        )
        self.memory = FixedMemoryBank(max_size=memory_size)
        
        # 直感スコアの重み
        self.weights = {
            "alpha": 0.4,  # 複雑さの重み
            "beta": 0.3,   # メモリ距離の重み
            "gamma": 0.3   # 不確実性の重み
        }
        
        # 閾値
        self.tau1 = tau1  # Skip閾値
        self.tau2 = tau2  # Reason閾値
        self.theta1 = theta1  # メモリ保存閾値（予測誤差）
        self.theta2 = theta2  # メモリ保存閾値（結果価値）
        
        # コンテキスト履歴
        self.context_history = []
        
        # メトリクス
        self.metrics = {
            "skip_count": 0,
            "retrieve_count": 0,
            "reason_count": 0,
            "total_tokens": 0,
            "total_latency": 0.0
        }
    
    def _estimate_complexity(self, text: str) -> float:
        """入力の複雑さを推定"""
        num_tokens = len(text.split())
        special_chars = sum(c.isdigit() or c in "+-*/()[]{}=" for c in text)
        tech_density = special_chars / max(len(text), 1)
        complexity = (num_tokens / 100) + tech_density
        return min(complexity, 2.0)
    
    def _estimate_uncertainty(self, text: str) -> float:
        """不確実性を推定"""
        uncertainty_keywords = ["how", "why", "what", "when", "where", "which", "explain", "describe", "analyze", "complex"]
        text_lower = text.lower()
        matches = sum(kw in text_lower for kw in uncertainty_keywords)
        return min(matches / 5.0, 1.0)
    
    def compute_intuition_score(self, input_text: str) -> float:
        """直感スコアを計算"""
        complexity = self._estimate_complexity(input_text)
        memory_distance = self.memory.get_min_distance(input_text)
        uncertainty = self._estimate_uncertainty(input_text)
        
        score = (
            self.weights["alpha"] * complexity +
            self.weights["beta"] * memory_distance +
            self.weights["gamma"] * uncertainty
        )
        return score
    
    def decide_action(self, score: float) -> str:
        """三値判断"""
        if score < self.tau1:
            return "Skip"
        elif score < self.tau2:
            return "Retrieve"
        else:
            return "Reason"
    
    def generate_response(
        self, 
        input_text: str,
        ground_truth: str = None
    ) -> Dict:
        """推論を実行 (Transformers実装)"""
        start_time = time.time()
        
        # 1. 直感スコア計算
        intuition_score = self.compute_intuition_score(input_text)
        action = self.decide_action(intuition_score)
        
        # 2. プロンプト生成
        if action == "Skip":
            prompt = f"Question: {input_text}\nAnswer briefly:"
            max_new_tokens = 20
            self.metrics["skip_count"] += 1
            
        elif action == "Retrieve":
            memories = self.memory.retrieve(input_text, k=3)
            memory_text = "\n".join([f"- {m[0]}" for m in memories])
            prompt = f"Reference:\n{memory_text}\n\nQuestion: {input_text}\nAnswer:"
            max_new_tokens = 100
            self.metrics["retrieve_count"] += 1
            
        else:  # Reason
            prompt = f"Question: {input_text}\nThink step-by-step and solve:"
            max_new_tokens = 300
            self.metrics["reason_count"] += 1
        
        # 3. 推論実行
        inputs = self.tokenizer(prompt, return_tensors="pt").to(self.device)
        with torch.no_grad():
            output_ids = self.model.generate(
                **inputs,
                max_new_tokens=max_new_tokens,
                do_sample=False,
                pad_token_id=self.tokenizer.eos_token_id
            )
        
        # 入力トークンを除去して応答のみ抽出
        response = self.tokenizer.decode(output_ids[0][inputs.input_ids.shape[1]:], skip_special_tokens=True).strip()
        
        # 4. メトリクス更新
        latency = time.time() - start_time
        num_new_tokens = len(output_ids[0]) - inputs.input_ids.shape[1]
        
        self.metrics["total_tokens"] += num_new_tokens
        self.metrics["total_latency"] += latency
        
        # 5. メモリ更新（簡易判定）
        if ground_truth is not None:
            # 予測誤差の簡易計算（正解が含まれているか等、タスクに合わせて調整が必要）
            prediction_error = float(ground_truth.lower() not in response.lower())
            outcome_value = 1.0  # MVP
            importance = prediction_error * outcome_value
            
            if prediction_error > self.theta1 or outcome_value > self.theta2:
                self.memory.add_episode(input_text, response, importance)
        
        return {
            "response": response,
            "action": action,
            "intuition_score": intuition_score,
            "latency": latency,
            "num_tokens": num_new_tokens
        }

    def get_metrics(self) -> Dict:
        total_decisions = self.metrics["skip_count"] + self.metrics["retrieve_count"] + self.metrics["reason_count"]
        return {
            "skip_ratio": self.metrics["skip_count"] / max(total_decisions, 1),
            "retrieve_ratio": self.metrics["retrieve_count"] / max(total_decisions, 1),
            "reason_ratio": self.metrics["reason_count"] / max(total_decisions, 1),
            "avg_tokens": self.metrics["total_tokens"] / max(total_decisions, 1),
            "avg_latency": self.metrics["total_latency"] / max(total_decisions, 1)
        }
