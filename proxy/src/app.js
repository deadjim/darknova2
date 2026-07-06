import express from 'express';

import { LruCache } from './cache.js';
import { RateLimiter } from './rateLimit.js';
import { requestHash } from './hash.js';
import { dialogueRequestSchema, newsRequestSchema, validate } from './schemas.js';
import {
  DIALOGUE_SYSTEM,
  NEWS_SYSTEM,
  dialogueUserPrompt,
  newsUserPrompt,
  renderSystem,
} from './prompts.js';
import { BadApiKeyError, LlmUnavailableError, generateProse } from './anthropic.js';
import { clampWords, tidyProse } from './text.js';

/**
 * Build the express app. `clientFactory(apiKey)` must return an object with
 * `messages.create(params, options)` — the real Anthropic SDK in production,
 * a mock in tests.
 *
 * @param {{
 *   config: ReturnType<typeof import('./config.js').loadConfig>,
 *   clientFactory: (apiKey: string) => {messages: {create: Function}},
 *   now?: () => number,
 * }} deps
 */
export function createApp({ config, clientFactory, now = Date.now }) {
  const app = express();
  app.set('trust proxy', config.trustProxy);
  app.disable('x-powered-by');

  const cache = new LruCache({ maxEntries: config.cache.maxEntries, now });
  const limiter = new RateLimiter({ ...config.rateLimit, now });

  // --- CORS (Flutter web builds) -----------------------------------------
  const allowAny = config.allowedOrigins.includes('*');
  app.use((req, res, next) => {
    const origin = req.headers.origin;
    if (origin && (allowAny || config.allowedOrigins.includes(origin))) {
      res.set('Access-Control-Allow-Origin', allowAny ? '*' : origin);
      res.set('Vary', 'Origin');
      res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      res.set('Access-Control-Allow-Headers', 'Content-Type, X-Api-Key');
      res.set('Access-Control-Max-Age', '86400');
    }
    if (req.method === 'OPTIONS') return res.status(204).end();
    next();
  });

  app.use(express.json({ limit: '32kb' }));

  // --- Health -------------------------------------------------------------
  app.get('/healthz', (req, res) => {
    res.json({ ok: true, model: config.model });
  });

  // --- Rate limiting (everything below this point) ------------------------
  app.use((req, res, next) => {
    const key = req.ip ?? 'unknown';
    const { allowed, retryAfterSec } = limiter.take(key);
    if (!allowed) {
      res.set('Retry-After', String(retryAfterSec));
      return res.status(429).json({ error: 'rate_limited', retryAfterSec });
    }
    next();
  });

  // --- Generation endpoints ----------------------------------------------
  const makeHandler = ({ schema, systemTemplate, buildUserPrompt, ttlMs }) =>
    async (req, res) => {
      const parsed = validate(schema, req.body);
      if (!parsed.ok) {
        return res.status(400).json({ error: 'invalid_request', issues: parsed.issues });
      }
      const body = parsed.data;

      const key = requestHash(req.path, config.model, body);
      const cached = cache.get(key);
      if (cached !== undefined) {
        res.set('X-Cache', 'HIT');
        return res.json({ text: cached, model: config.model, cached: true });
      }

      // BYOK: an X-Api-Key header overrides the server's key.
      const apiKey = req.get('x-api-key') || config.anthropicApiKey;
      if (!apiKey) {
        // No key anywhere — behave like an outage so the engine falls back.
        return res.status(503).json({ error: 'llm_unavailable', reason: 'no_api_key' });
      }

      try {
        const raw = await generateProse(clientFactory(apiKey), {
          model: config.model,
          system: renderSystem(systemTemplate, body.maxWords),
          user: buildUserPrompt(body),
          maxTokens: config.llmMaxTokens,
          timeoutMs: config.llmTimeoutMs,
        });
        const text = clampWords(tidyProse(raw), body.maxWords);
        cache.set(key, text, ttlMs);
        res.set('X-Cache', 'MISS');
        return res.json({ text, model: config.model, cached: false });
      } catch (err) {
        if (err instanceof BadApiKeyError) {
          return res.status(401).json({ error: 'invalid_api_key' });
        }
        if (err instanceof LlmUnavailableError) {
          return res.status(503).json({ error: 'llm_unavailable' });
        }
        throw err;
      }
    };

  app.post(
    '/v1/dialogue',
    makeHandler({
      schema: dialogueRequestSchema,
      systemTemplate: DIALOGUE_SYSTEM,
      buildUserPrompt: dialogueUserPrompt,
      ttlMs: config.cache.dialogueTtlMs,
    }),
  );

  app.post(
    '/v1/news',
    makeHandler({
      schema: newsRequestSchema,
      systemTemplate: NEWS_SYSTEM,
      buildUserPrompt: newsUserPrompt,
      ttlMs: config.cache.newsTtlMs,
    }),
  );

  app.use((req, res) => {
    res.status(404).json({ error: 'not_found' });
  });

  // Malformed JSON bodies and anything unexpected.
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    if (err?.type === 'entity.parse.failed' || err instanceof SyntaxError) {
      return res.status(400).json({ error: 'invalid_json' });
    }
    if (err?.type === 'entity.too.large') {
      return res.status(413).json({ error: 'payload_too_large' });
    }
    console.error('unhandled error:', err);
    res.status(500).json({ error: 'internal_error' });
  });

  return app;
}
