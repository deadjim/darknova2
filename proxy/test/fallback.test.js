import { test } from 'node:test';
import assert from 'node:assert/strict';

import { startServer, dialogueBody, mockFactory } from './helpers.js';

test('fallback contract — the game must always be able to use canned prose', async (t) => {
  await t.test('upstream error becomes a 503', async () => {
    const server = await startServer({
      respond: () => {
        const err = new Error('overloaded');
        err.status = 529;
        throw err;
      },
    });
    t.after(() => server.close());
    const { status, json } = await server.post('/v1/dialogue', dialogueBody());
    assert.equal(status, 503);
    assert.equal(json.error, 'llm_unavailable');
  });

  await t.test('a hung upstream call times out into a 503', async () => {
    const server = await startServer({
      env: { LLM_TIMEOUT_MS: '100' },
      respond: () => new Promise(() => {}), // never resolves
    });
    t.after(() => server.close());
    const start = Date.now();
    const { status, json } = await server.post('/v1/dialogue', dialogueBody());
    assert.equal(status, 503);
    assert.equal(json.error, 'llm_unavailable');
    assert.ok(Date.now() - start < 2000, 'responded well before any default HTTP timeout');
  });

  await t.test('a model refusal becomes a 503', async () => {
    const server = await startServer({
      respond: () => ({ stop_reason: 'refusal', content: [] }),
    });
    t.after(() => server.close());
    const { status } = await server.post('/v1/dialogue', dialogueBody());
    assert.equal(status, 503);
  });

  await t.test('an empty model response becomes a 503', async () => {
    const server = await startServer({
      respond: () => ({ stop_reason: 'end_turn', content: [] }),
    });
    t.after(() => server.close());
    const { status } = await server.post('/v1/dialogue', dialogueBody());
    assert.equal(status, 503);
  });

  await t.test('failures are not cached — a later success goes through', async () => {
    let failFirst = true;
    const server = await startServer({
      respond: () => {
        if (failFirst) {
          failFirst = false;
          throw new Error('transient');
        }
        return { stop_reason: 'end_turn', content: [{ type: 'text', text: 'Back online, Commander.' }] };
      },
    });
    t.after(() => server.close());
    const r1 = await server.post('/v1/dialogue', dialogueBody());
    assert.equal(r1.status, 503);
    const r2 = await server.post('/v1/dialogue', dialogueBody());
    assert.equal(r2.status, 200);
    assert.equal(r2.json.text, 'Back online, Commander.');
  });

  await t.test('no server key and no BYOK key is a 503, not a crash', async () => {
    const server = await startServer({ env: { ANTHROPIC_API_KEY: '' } });
    t.after(() => server.close());
    const { status, json } = await server.post('/v1/dialogue', dialogueBody());
    assert.equal(status, 503);
    assert.equal(json.reason, 'no_api_key');
    assert.equal(server.factory.calls.length, 0);
  });
});

test('prose contract post-processing', async (t) => {
  await t.test('wrapping quotes and markdown are stripped, word cap enforced', async () => {
    const longLine = `"**${Array.from({ length: 60 }, (_, i) => `word${i}`).join(' ')}**"`;
    const server = await startServer({
      respond: () => ({ stop_reason: 'end_turn', content: [{ type: 'text', text: longLine }] }),
    });
    t.after(() => server.close());
    const { status, json } = await server.post('/v1/dialogue', dialogueBody({ maxWords: 10 }));
    assert.equal(status, 200);
    assert.ok(!json.text.includes('"'));
    assert.ok(!json.text.includes('**'));
    assert.ok(json.text.split(/\s+/).length <= 11); // 10 words + ellipsis marker
  });

  await t.test('the model is called with the strict prose-only system prompt', async () => {
    const factory = mockFactory();
    const server = await startServer({ factory });
    t.after(() => server.close());
    await server.post('/v1/dialogue', dialogueBody({ maxWords: 25 }));
    const call = factory.calls[0];
    assert.equal(call.params.model, 'claude-haiku-4-5-20251001');
    assert.match(call.params.system, /Output ONLY the spoken line/);
    assert.match(call.params.system, /maximum length: 25 words/i);
    assert.match(call.params.messages[0].content, /already decided by the game engine/);
    assert.equal(call.options.maxRetries, 0);
    assert.ok(call.options.timeout > 0);
  });
});
