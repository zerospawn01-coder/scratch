import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
from collections import deque
from dataclasses import dataclass
from typing import List, Tuple

@dataclass
class Episode:
    """エピソード記憶の単位"""
    text: str
    embedding: np.ndarray
    answer: str
    importance: float
    timestamp: int

class FixedMemoryBank:
    """固定サイズのエピソード記憶"""
    
    def __init__(self, max_size: int = 1000, embed_fn=None):
        self.max_size = max_size
        self.memories = []
        self.embed_fn = embed_fn or self._simple_embed
        self.timestamp = 0
        
    def _simple_embed(self, text: str) -> np.ndarray:
        """簡易埋め込み（TF-IDF風）"""
        # Phase 1では単純なBag-of-Words
        words = text.lower().split()
        vocab = set(words)
        vector = np.zeros(512)  # 固定次元
        for i, word in enumerate(vocab):
            idx = hash(word) % 512
            vector[idx] += 1
        return vector / (np.linalg.norm(vector) + 1e-8)
    
    def add_episode(self, text: str, answer: str, importance: float):
        """エピソードを追加（重要度ベースで管理）"""
        embedding = self.embed_fn(text)
        episode = Episode(
            text=text,
            embedding=embedding,
            answer=answer,
            importance=importance,
            timestamp=self.timestamp
        )
        self.timestamp += 1
        
        # メモリが満杯なら、重要度が最小のものを削除
        if len(self.memories) >= self.max_size:
            min_idx = min(range(len(self.memories)), 
                         key=lambda i: self.memories[i].importance)
            self.memories.pop(min_idx)
        
        self.memories.append(episode)
    
    def retrieve(self, query: str, k: int = 3) -> List[Tuple[str, float]]:
        """類似度ベースでTop-k検索"""
        if not self.memories:
            return []
        
        query_emb = self.embed_fn(query)
        embeddings = np.stack([m.embedding for m in self.memories])
        
        # コサイン類似度計算
        similarities = cosine_similarity(
            query_emb.reshape(1, -1), 
            embeddings
        )[0]
        
        # Top-k取得
        top_k_indices = np.argsort(similarities)[-k:][::-1]
        results = [
            (self.memories[i].text, similarities[i]) 
            for i in top_k_indices
        ]
        
        return results
    
    def get_min_distance(self, query: str) -> float:
        """最近傍エピソードとの距離"""
        if not self.memories:
            return 1.0  # メモリが空なら最大距離
        
        results = self.retrieve(query, k=1)
        if not results:
            return 1.0
        
        return 1.0 - results[0][1]  # 距離 = 1 - 類似度
