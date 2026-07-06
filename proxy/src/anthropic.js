import Anthropic from '@anthropic-ai/sdk';

/**
 * Default client factory: returns an Anthropic client for the given API key,
 * memoizing per key (BYOK clients get their own instance). Bounded so a flood
 * of bogus BYOK keys can't grow memory without limit.
 *
 * Tests replace this with a mock factory — no live API calls in tests.
 * @returns {(apiKey: string) => {messages: {create: Function}}}
 */
export function defaultClientFactory() {
  const clients = new Map();
  const MAX_CLIENTS = 32;
  return (apiKey) => {
    let client = clients.get(apiKey);
    if (!client) {
      if (clients.size >= MAX_CLIENTS) {
        clients.delete(clients.keys().next().value);
      }
      client = new Anthropic({ apiKey });
      clients.set(apiKey, client);
    }
    return client;
  };
}

/** Error used to signal the engine-side fallback should take over. */
export class LlmUnavailableError extends Error {
  constructor(message, { cause } = {}) {
    super(message, { cause });
    this.name = 'LlmUnavailableError';
  }
}

/** Thrown when a BYOK key is rejected upstream — surfaced as 401, not 503. */
export class BadApiKeyError extends Error {
  constructor(message) {
    super(message);
    this.name = 'BadApiKeyError';
  }
}

/**
 * One prose-generation call with a hard wall-clock deadline. Any upstream
 * failure (timeout, 5xx, overload, refusal, empty output) becomes
 * LlmUnavailableError → HTTP 503 → the game's canned prose kicks in.
 *
 * @param {{messages: {create: Function}}} client
 * @param {{model: string, system: string, user: string, maxTokens: number, timeoutMs: number}} opts
 * @returns {Promise<string>}
 */
export async function generateProse(client, { model, system, user, maxTokens, timeoutMs }) {
  let timer;
  const deadline = new Promise((_, reject) => {
    timer = setTimeout(
      () => reject(new LlmUnavailableError(`LLM call exceeded ${timeoutMs}ms`)),
      timeoutMs,
    );
    timer.unref?.();
  });

  let message;
  try {
    message = await Promise.race([
      client.messages.create(
        {
          model,
          max_tokens: maxTokens,
          system,
          messages: [{ role: 'user', content: user }],
        },
        // Real SDK also enforces the deadline itself; no automatic retries —
        // the game would rather fall back than wait.
        { timeout: timeoutMs, maxRetries: 0 },
      ),
      deadline,
    ]);
  } catch (err) {
    if (err instanceof LlmUnavailableError) throw err;
    if (err?.status === 401 || err?.status === 403) {
      throw new BadApiKeyError('Upstream rejected the API key');
    }
    throw new LlmUnavailableError('Upstream LLM call failed', { cause: err });
  } finally {
    clearTimeout(timer);
  }

  if (message?.stop_reason === 'refusal') {
    throw new LlmUnavailableError('Model refused; use fallback prose');
  }
  const text = (message?.content ?? [])
    .filter((block) => block.type === 'text')
    .map((block) => block.text)
    .join(' ')
    .trim();
  if (!text) throw new LlmUnavailableError('Empty model response');
  return text;
}
