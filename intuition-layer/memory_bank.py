import numpy as np
from dataclasses import dataclass
from typing import List, Tuple


def _cosine_similarity(query: np.ndarray, matrix: np.ndarray) -> np.ndarray:
    """Compute cosine similarity between a query vector and a matrix of vectors.

    ``query`` is flattened to 1-D so embeddings returned as (1, d) or (d, 1)
    by user-supplied ``embed_fn`` are handled correctly.  ``matrix`` must be
    2-D with the same feature dimension as ``query``.
    """
    query = np.asarray(query, dtype=float).reshape(-1)
    matrix = np.asarray(matrix, dtype=float)
    if matrix.ndim != 2:
        raise ValueError(f"matrix must be 2-D, got shape {matrix.shape}")
    if matrix.shape[1] != query.shape[0]:
        raise ValueError(
            f"Dimension mismatch: query has {query.shape[0]} dims, "
            f"matrix has {matrix.shape[1]} dims"
        )
    query_norm = np.linalg.norm(query) + 1e-8
    matrix_norms = np.linalg.norm(matrix, axis=1) + 1e-8
    return matrix @ query / (matrix_norms * query_norm)

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
        similarities = _cosine_similarity(query_emb, embeddings)
        
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
