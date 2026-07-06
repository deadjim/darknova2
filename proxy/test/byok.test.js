import { test } from 'node:test';
import assert from 'node:assert/strict';

import { startServer, dialogueBody, mockFactory } from './helpers.js';

test('BYOK (X-Api-Key header)', async (t) => {
  await t.test('uses the server key by default', async () => {
    const factory = mockFactory();
    const server = await startServer({ factory });
    t.after(() => server.close());
    await server.post('/v1/dialogue', dialogueBody());
    assert.equal(factory.calls[0].apiKey, 'sk-server-key');
  });

  await t.test('X-Api-Key overrides the server key', async () => {
    const factory = mockFactory();
    const server = await startServer({ factory });
    t.after(() => server.close());
    await server.post('/v1/dialogue', dialogueBody({ maxWords: 22 }), {
      'x-api-key': 'sk-player-own-key',
    });
    assert.equal(factory.calls[0].apiKey, 'sk-player-own-key');
  });

  await t.test('BYOK works even when the server has no key', async () => {
    const factory = mockFactory();
    const server = await startServer({ factory, env: { ANTHROPIC_API_KEY: '' } });
    t.after(() => server.close());
    const { status } = await server.post('/v1/dialogue', dialogueBody(), {
      'x-api-key': 'sk-player-own-key',
    });
    assert.equal(status, 200);
    assert.equal(factory.calls[0].apiKey, 'sk-player-own-key');
  });

  await t.test('an upstream-rejected key is a 401, not a 503', async () => {
    const server = await startServer({
      respond: () => {
        const err = new Error('authentication_error');
        err.status = 401;
        throw err;
      },
    });
    t.after(() => server.close());
    const { status, json } = await server.post('/v1/dialogue', dialogueBody(), {
      'x-api-key': 'sk-bogus',
    });
    assert.equal(status, 401);
    assert.equal(json.error, 'invalid_api_key');
  });
});
