import { loadConfig } from './config.js';
import { createApp } from './app.js';
import { defaultClientFactory } from './anthropic.js';

const config = loadConfig();

if (!config.anthropicApiKey) {
  console.warn(
    'warning: ANTHROPIC_API_KEY is not set — only BYOK requests (X-Api-Key header) will work.',
  );
}

const app = createApp({ config, clientFactory: defaultClientFactory() });

const server = app.listen(config.port, () => {
  console.log(`darknova-proxy listening on :${config.port} (model: ${config.model})`);
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    console.log(`${signal} received, shutting down`);
    server.close(() => process.exit(0));
    // Don't hang forever on open keep-alive sockets.
    setTimeout(() => process.exit(0), 5000).unref();
  });
}
