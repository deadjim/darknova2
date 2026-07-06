import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';

/** A well-formed dialogue request body for tests. */
export function dialogueBody(overrides = {}) {
  return {
    speaker: { role: 'pirate', shipType: 'Gnat' },
    outcome: { action: 'demand_credits', details: { credits: 500 } },
    context: { systemName: 'Tarchannen', commanderName: 'Jameson' },
    ...overrides,
  };
}

/** A well-formed news request body for tests. */
export function newsBody(overrides = {}) {
  return {
    event: { type: 'drought', summary: 'Drought on Regulas enters its third week; water reserves low.' },
    system: { name: 'Regulas', government: 'Feudal State' },
    gameDay: 42,
    seed: 'galaxy-1',
    ...overrides,
  };
}

/**
 * Mock Anthropic client factory. Records every (apiKey, params) call.
 * `respond` decides behavior per call; defaults to a canned prose reply.
 */
export function mockFactory(respond) {
  const calls = [];
  const factory = (apiKey) => ({
    messages: {
      async create(params, options) {
        const call = { apiKey, params, options };
        calls.push(call);
        if (respond) return respond(call);
        return {
          stop_reason: 'end_turn',
          content: [{ type: 'text', text: 'Hand over the credits and nobody gets vaporized.' }],
        };
      },
    },
  });
  factory.calls = calls;
  return factory;
}

/**
 * Boot the app on an ephemeral port with a mock client factory.
 * Returns { baseUrl, factory, close, post }.
 */
export async function startServer({ env = {}, respond, factory } = {}) {
  const config = loadConfig({
    ANTHROPIC_API_KEY: 'sk-server-key',
    LLM_TIMEOUT_MS: '250',
    ...env,
  });
  const f = factory ?? mockFactory(respond);
  const app = createApp({ config, clientFactory: f });
  const server = await new Promise((resolve) => {
    const s = app.listen(0, () => resolve(s));
  });
  const { port } = server.address();
  const baseUrl = `http://127.0.0.1:${port}`;

  const post = async (path, body, headers = {}) => {
    const res = await fetch(`${baseUrl}${path}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...headers },
      body: typeof body === 'string' ? body : JSON.stringify(body),
    });
    let json = null;
    try {
      json = await res.json();
    } catch {
      // non-JSON response
    }
    return { status: res.status, headers: res.headers, json };
  };

  return {
    baseUrl,
    factory: f,
    post,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}
