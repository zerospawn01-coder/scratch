/**
 * GovernanceUtils.ts - Deterministic Hashing and Canonicalization
 * 
 * Ensures all governance objects are serialized and hashed identically
 * across sessions, preventing schema drift or ordering noise.
 */

export class GovernanceUtils {
  /**
   * Deterministic JSON stringification (key-ordered).
   */
  static canonicalize(obj: any): string {
    if (obj === null || typeof obj !== 'object') {
      return JSON.stringify(obj);
    }

    if (Array.isArray(obj)) {
      return '[' + obj.map(item => this.canonicalize(item)).join(',') + ']';
    }

    const keys = Object.keys(obj).sort();
    return '{' + 
      keys
        .map(k => `"${k}":${this.canonicalize(obj[k])}`)
        .join(',') + 
      '}';
  }

  /**
   * Generates a deterministic SHA-256 hash of a canonicalized surface.
   * Simple Web Crypto API wrapper (or fallback for Node if needed).
   */
  static async generateHash(data: string): Promise<string> {
    const msgUint8 = new TextEncoder().encode(data);
    const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  }

  /**
   * Sync fallback (non-cryptographic but deterministic) for immediate use if needed.
   * This is a simple DJB2/FNV style hash to avoid async overhead in tight loops.
   */
  static generateFastHash(data: string): string {
    let hash = 5381;
    for (let i = 0; i < data.length; i++) {
        hash = (hash * 33) ^ data.charCodeAt(i);
    }
    return (hash >>> 0).toString(16);
  }
}
