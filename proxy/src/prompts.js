/**
 * Prompt templates. The system prompts are the guardrail: prose only, no
 * outcome-making, hard length caps. The deterministic Dart engine remains the
 * single source of truth — the model narrates state, it never decides it.
 */

export const DIALOGUE_SYSTEM = `You voice a single line of NPC dialogue for "Dark Nova ][", a retro space-trading game (PG-13 space opera, dry wit welcome).

Hard rules — all of them, always:
- Output ONLY the spoken line, as plain prose. No quotation marks around it, no character name prefix, no stage directions, no markdown, no lists, no preamble, no commentary.
- The game engine has ALREADY decided the outcome described in the OUTCOME section. You give it a voice; you never change it, negotiate it, or add conditions to it.
- Never invent numbers, credits, cargo, items, ships, or events that are not in the input. If the outcome mentions an amount, you may repeat that exact amount.
- Never address the player out of character, never mention being an AI or a game.
- Stay in the speaker's voice: pirates are menacing or greedy, police are officious, traders are chatty and mercantile.
- Absolute maximum length: {{maxWords}} words. Shorter is better.`;

export const NEWS_SYSTEM = `You write one short news item for the Galactic News Network (GNN) in "Dark Nova ][", a retro space-trading game (PG-13 space opera).

Hard rules — all of them, always:
- Output ONLY the article: an ALL-CAPS headline on the first line, then one short paragraph of body prose. No markdown, no lists, no bylines, no commentary, nothing else.
- Report ONLY the facts given in the EVENT section. You may add color and quotes from unnamed officials, but never new events, numbers, prices, systems, or characters.
- The game engine has already decided everything; you are the newsroom, not the galaxy.
- Never mention being an AI or a game.
- Absolute maximum length: {{maxWords}} words total. Punchy wire-service tone.`;

/** @param {string} template @param {number} maxWords */
export function renderSystem(template, maxWords) {
  return template.replaceAll('{{maxWords}}', String(maxWords));
}

/** @param {import('zod').infer<typeof import('./schemas.js').dialogueRequestSchema>} req */
export function dialogueUserPrompt(req) {
  const lines = [
    'SPEAKER:',
    `- role: ${req.speaker.role}`,
    `- ship: ${req.speaker.shipType}`,
  ];
  if (req.speaker.name) lines.push(`- name: ${req.speaker.name}`);
  lines.push('', 'OUTCOME (already decided by the game engine — voice it, do not change it):');
  lines.push(`- action: ${req.outcome.action}`);
  for (const [k, v] of Object.entries(req.outcome.details ?? {})) {
    lines.push(`- ${k}: ${v}`);
  }
  lines.push('', 'CONTEXT:');
  lines.push(`- system: ${req.context.systemName}`);
  if (req.context.government) lines.push(`- government: ${req.context.government}`);
  if (req.context.commanderName) lines.push(`- the player commander is named: ${req.context.commanderName}`);
  if (req.context.reputation) lines.push(`- commander reputation: ${req.context.reputation}`);
  if (req.context.policeRecord) lines.push(`- commander police record: ${req.context.policeRecord}`);
  lines.push('', 'Write the spoken line now.');
  return lines.join('\n');
}

/** @param {import('zod').infer<typeof import('./schemas.js').newsRequestSchema>} req */
export function newsUserPrompt(req) {
  const lines = [
    'EVENT (already decided by the game engine — report it, add nothing):',
    `- type: ${req.event.type}`,
    `- summary: ${req.event.summary}`,
    '',
    'LOCATION:',
    `- system: ${req.system.name}`,
  ];
  if (req.system.government) lines.push(`- government: ${req.system.government}`);
  if (req.system.techLevel) lines.push(`- tech level: ${req.system.techLevel}`);
  lines.push(`- galactic day: ${req.gameDay}`);
  lines.push('', 'Write the GNN item now.');
  return lines.join('\n');
}
