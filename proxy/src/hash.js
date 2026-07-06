import { createHash } from 'node:crypto';

/**
 * Deterministic JSON stringify: object keys are sorted recursively so that
 * two semantically identical requests hash to the same cache key.
 * @param {unknown} value
 * @returns {string}
 */
export function stableStringify(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(',')}]`;
  }
  const keys = Object.keys(value).sort();
  const parts = keys.map((k) => `${JSON.stringify(k)}:${stableStringify(value[k])}`);
  return `{${parts.join(',')}}`;
}

/**
 * Cache key for a validated request.
 * @param {string} endpoint
 * @param {string} model
 * @param {unknown} body
 */
export function requestHash(endpoint, model, body) {
  return createHash('sha256')
    .update(`${endpoint}\0${model}\0${stableStringify(body)}`)
    .digest('hex');
}
