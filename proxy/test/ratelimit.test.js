import { test } from 'node:test';
import assert from 'node:assert/strict';

import { RateLimiter } from '../src/rateLimit.js';
import { startServer, dialogueBody } from './helpers.js';

test('RateLimiter token bucket', async (t) => {
  await t.test('allows burst then blocks', () => {
    let clock = 0;
    const limiter = new RateLimiter({ burst: 3, perMinute: 60, now: () => clock });
    assert.equal(limiter.take('a').allowed, true);
    assert.equal(limiter.take('a').allowed, true);
    assert.equal(limiter.take('a').allowed, true);
    const denied = limiter.take('a');
    assert.equal(denied.allowed, false);
    assert.ok(denied.retryAfterSec >= 1);
  });

  await t.test('refills over time', () => {
    let clock = 0;
    const limiter = new RateLimiter({ burst: 1, perMinute: 60, now: () => clock });
    assert.equal(limiter.take('a').allowed, true);
    assert.equal(limiter.take('a').allowed, false);
    clock += 1000; // one token per second at 60/min
    assert.equal(limiter.take('a').allowed, true);
  });

  await t.test('buckets are per key', () => {
    let clock = 0;
    const limiter = new RateLimiter({ burst: 1, perMinute: 60, now: () => clock });
    assert.equal(limiter.take('a').allowed, true);
    assert.equal(limiter.take('b').allowed, true);
    assert.equal(limiter.take('a').allowed, false);
  });
});

test('HTTP rate limiting', async (t) => {
  const server = await startServer({
    env: { RATE_LIMIT_BURST: '2', RATE_LIMIT_PER_MINUTE: '1' },
  });
  t.after(() => server.close());

  await t.test('429 with Retry-After after the burst is spent', async () => {
    const r1 = await server.post('/v1/dialogue', dialogueBody());
    const r2 = await server.post('/v1/dialogue', dialogueBody({ maxWords: 30 }));
    assert.equal(r1.status, 200);
    assert.equal(r2.status, 200);
    const r3 = await server.post('/v1/dialogue', dialogueBody({ maxWords: 31 }));
    assert.equal(r3.status, 429);
    assert.equal(r3.json.error, 'rate_limited');
    assert.ok(Number(r3.headers.get('retry-after')) >= 1);
  });

  await t.test('healthz is exempt from rate limiting', async () => {
    const res = await fetch(`${server.baseUrl}/healthz`);
    assert.equal(res.status, 200);
  });
});
