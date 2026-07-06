import { test } from 'node:test';
import assert from 'node:assert/strict';

import { LruCache } from '../src/cache.js';
import { stableStringify, requestHash } from '../src/hash.js';
import { startServer, dialogueBody, newsBody } from './helpers.js';

test('LruCache', async (t) => {
  await t.test('expires entries after their TTL', () => {
    let clock = 0;
    const cache = new LruCache({ maxEntries: 10, now: () => clock });
    cache.set('k', 'v', 1000);
    assert.equal(cache.get('k'), 'v');
    clock = 1001;
    assert.equal(cache.get('k'), undefined);
  });

  await t.test('evicts least-recently-used entry at capacity', () => {
    const cache = new LruCache({ maxEntries: 2, now: () => 0 });
    cache.set('a', 1, 10_000);
    cache.set('b', 2, 10_000);
    cache.get('a'); // refresh a's recency → b is now LRU
    cache.set('c', 3, 10_000);
    assert.equal(cache.get('a'), 1);
    assert.equal(cache.get('b'), undefined);
    assert.equal(cache.get('c'), 3);
  });
});

test('request hashing', async (t) => {
  await t.test('is key-order independent', () => {
    assert.equal(
      stableStringify({ a: 1, b: { d: 2, c: [3, { f: 4, e: 5 }] } }),
      stableStringify({ b: { c: [3, { e: 5, f: 4 }], d: 2 }, a: 1 }),
    );
  });

  await t.test('differs by endpoint and body', () => {
    const body = dialogueBody();
    assert.notEqual(
      requestHash('/v1/dialogue', 'm', body),
      requestHash('/v1/news', 'm', body),
    );
    assert.notEqual(
      requestHash('/v1/dialogue', 'm', body),
      requestHash('/v1/dialogue', 'm', { ...body, maxWords: 12 }),
    );
  });
});

test('HTTP response caching', async (t) => {
  await t.test('identical dialogue requests hit the cache (one LLM call)', async () => {
    const server = await startServer();
    t.after(() => server.close());

    const r1 = await server.post('/v1/dialogue', dialogueBody());
    const r2 = await server.post('/v1/dialogue', dialogueBody());
    assert.equal(r1.status, 200);
    assert.equal(r2.status, 200);
    assert.equal(r1.headers.get('x-cache'), 'MISS');
    assert.equal(r2.headers.get('x-cache'), 'HIT');
    assert.equal(r2.json.cached, true);
    assert.equal(r2.json.text, r1.json.text);
    assert.equal(server.factory.calls.length, 1);
  });

  await t.test('same news event on the same day/seed is served once', async () => {
    const server = await startServer();
    t.after(() => server.close());

    await server.post('/v1/news', newsBody());
    await server.post('/v1/news', newsBody());
    assert.equal(server.factory.calls.length, 1);

    // A different game day is a different article.
    await server.post('/v1/news', newsBody({ gameDay: 43 }));
    assert.equal(server.factory.calls.length, 2);
  });

  await t.test('key order in the JSON body does not defeat the cache', async () => {
    const server = await startServer();
    t.after(() => server.close());

    const body = dialogueBody();
    await server.post('/v1/dialogue', body);
    // Same content, different key order.
    const reordered = JSON.parse(JSON.stringify({
      context: body.context,
      outcome: body.outcome,
      speaker: body.speaker,
    }));
    const r2 = await server.post('/v1/dialogue', reordered);
    assert.equal(r2.headers.get('x-cache'), 'HIT');
    assert.equal(server.factory.calls.length, 1);
  });
});
