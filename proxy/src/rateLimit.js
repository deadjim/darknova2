/**
 * Per-key (per-IP) token bucket rate limiter, in memory.
 * Each key gets `burst` tokens, refilled at `perMinute / 60000` tokens per ms.
 */
export class RateLimiter {
  /**
   * @param {{burst?: number, perMinute?: number, now?: () => number}} [opts]
   */
  constructor({ burst = 10, perMinute = 30, now = Date.now } = {}) {
    this.burst = burst;
    this.refillPerMs = perMinute / 60000;
    this.now = now;
    /** @type {Map<string, {tokens: number, updatedAt: number}>} */
    this.buckets = new Map();
  }

  /**
   * Try to take one token for `key`.
   * @param {string} key
   * @returns {{allowed: boolean, retryAfterSec: number}}
   */
  take(key) {
    const now = this.now();
    let bucket = this.buckets.get(key);
    if (!bucket) {
      bucket = { tokens: this.burst, updatedAt: now };
      this.buckets.set(key, bucket);
    } else {
      const elapsed = now - bucket.updatedAt;
      bucket.tokens = Math.min(this.burst, bucket.tokens + elapsed * this.refillPerMs);
      bucket.updatedAt = now;
    }
    if (bucket.tokens >= 1) {
      bucket.tokens -= 1;
      return { allowed: true, retryAfterSec: 0 };
    }
    const needed = 1 - bucket.tokens;
    const retryAfterSec = Math.max(1, Math.ceil(needed / this.refillPerMs / 1000));
    this.#prune(now);
    return { allowed: false, retryAfterSec };
  }

  /** Drop buckets that have fully refilled (idle clients) to bound memory. */
  #prune(now) {
    if (this.buckets.size < 10_000) return;
    for (const [key, bucket] of this.buckets) {
      const elapsed = now - bucket.updatedAt;
      if (bucket.tokens + elapsed * this.refillPerMs >= this.burst) {
        this.buckets.delete(key);
      }
    }
  }
}
