from datasets import load_dataset
from intuition_router import IntuitionRouter
from tqdm import tqdm
import json
import re

def extract_number(text: str) -> str:
    """テキストから最後の数値を抽出"""
    # 数値（整数・小数点）を探す。GSM8Kの正解は通常最後の方にある。
    numbers = re.findall(r'-?\d+\.?\d*', text)
    return numbers[-1] if numbers else ""

def evaluate_gsm8k_safety(router: IntuitionRouter, num_samples: int = 20) -> Dict:
    """GSM8K評価 (Phase A: Safety Run)"""
    print(f"Loading GSM8K dataset...")
    dataset = load_dataset("gsm8k", "main", split="test")
    dataset = dataset.shuffle(seed=42).select(range(num_samples))
    
    correct = 0
    results = []
    
    for i, example in enumerate(tqdm(dataset, desc="Safety Testing")):
        question = example["question"]
        # GSM8Kの正解は #### の後に数値がある
        answer_full = example["answer"]
        answer_num = answer_full.split("####")[1].strip()
        
        result = router.generate_response(question, ground_truth=answer_num)
        
        # 正解判定
        pred_num = extract_number(result["response"])
        is_correct = (pred_num == answer_num)
        
        if is_correct:
            correct += 1
        
        results.append({
            "id": i,
            "question": question,
            "ground_truth": answer_num,
            "prediction_number": pred_num,
            "action": result["action"],
            "score": f"{result['intuition_score']:.3f}",
            "correct": is_correct,
            "latency": f"{result['latency']:.3f}"
        })
    
    accuracy = correct / num_samples
    metrics = router.get_metrics()
    
    summary = {
        "accuracy": f"{accuracy:.2%}",
        "metrics": metrics,
        "sample_size": num_samples
    }
    
    # 詳細ログの保存
    with open("results_safety_phase_a.json", "w") as f:
        json.dump({
            "summary": summary,
            "results": results
        }, f, indent=2)
    
    return summary

if __name__ == "__main__":
    # Qwen-0.5B を使用した安全テストの実行
    router = IntuitionRouter(model_name="Qwen/Qwen2.5-0.5B-Instruct")
    
    print("\nStarting Phase A: Local Safety Run (20 samples)...")
    summary = evaluate_gsm8k_safety(router, num_samples=20)
    
    print("\n--- Phase A Summary ---")
    print(json.dumps(summary, indent=2))
    print("\nResults saved to 'results_safety_phase_a.json'")
