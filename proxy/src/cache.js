/**
 * Small in-memory LRU cache with per-entry TTL.
 * Map iteration order == insertion order, so the first key is always the
 * least-recently-used entry (we re-insert on read).
 */
export class LruCache {
  /**
   * @param {{maxEntries?: number, now?: () => number}} [opts]
   */
  constructor({ maxEntries = 500, now = Date.now } = {}) {
    this.maxEntries = maxEntries;
    this.now = now;
    /** @type {Map<string, {value: unknown, expiresAt: number}>} */
    this.map = new Map();
  }

  get size() {
    return this.map.size;
  }

  /** @param {string} key */
  get(key) {
    const entry = this.map.get(key);
    if (!entry) return undefined;
    if (entry.expiresAt <= this.now()) {
      this.map.delete(key);
      return undefined;
    }
    // Refresh recency.
    this.map.delete(key);
    this.map.set(key, entry);
    return entry.value;
  }

  /**
   * @param {string} key
   * @param {unknown} value
   * @param {number} ttlMs
   */
  set(key, value, ttlMs) {
    if (this.map.has(key)) this.map.delete(key);
    while (this.map.size >= this.maxEntries) {
      const oldest = this.map.keys().next().value;
      this.map.delete(oldest);
    }
    this.map.set(key, { value, expiresAt: this.now() + ttlMs });
  }

  clear() {
    this.map.clear();
  }
}
