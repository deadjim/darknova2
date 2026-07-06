/**
 * Configuration, sourced from environment variables. See ../.env.example.
 */

function int(value, fallback) {
  const n = Number.parseInt(value ?? '', 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

/**
 * @param {NodeJS.ProcessEnv} [env]
 */
export function loadConfig(env = process.env) {
  return {
    port: int(env.PORT, 8095),
    /** Server-side Anthropic key. Optional if every client brings its own (BYOK). */
    anthropicApiKey: env.ANTHROPIC_API_KEY ?? '',
    model: env.ANTHROPIC_MODEL || 'claude-haiku-4-5-20251001',
    allowedOrigins: (env.ALLOWED_ORIGINS ?? '*')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
    /** Hard deadline for one Claude call. On expiry the proxy answers 503 and
     *  the game's engine-side canned prose takes over. */
    llmTimeoutMs: int(env.LLM_TIMEOUT_MS, 3000),
    /** Max output tokens per Claude call (prose lines are short). */
    llmMaxTokens: int(env.LLM_MAX_TOKENS, 400),
    rateLimit: {
      burst: int(env.RATE_LIMIT_BURST, 10),
      perMinute: int(env.RATE_LIMIT_PER_MINUTE, 30),
    },
    cache: {
      maxEntries: int(env.CACHE_MAX_ENTRIES, 500),
      dialogueTtlMs: int(env.DIALOGUE_CACHE_TTL_MS, 15 * 60 * 1000),
      // News is deterministic per (seed, day, event) — cache it for a long time.
      newsTtlMs: int(env.NEWS_CACHE_TTL_MS, 24 * 60 * 60 * 1000),
    },
    /** Set TRUST_PROXY=1 when running behind nginx/caddy so req.ip is the real
     *  client address (rate limiting depends on it). */
    trustProxy: env.TRUST_PROXY === '1',
  };
}
