import { z } from 'zod';

/**
 * Request schemas. The contract that keeps the engine authoritative:
 * the client sends the *already-decided* outcome plus trimmed context;
 * the proxy returns prose only. Unknown fields are rejected (strict objects)
 * so the client can't smuggle instructions past validation.
 */

const shortStr = (max) => z.string().trim().min(1).max(max);

/** Everything the engine has already decided about a parley/hail beat. */
export const dialogueOutcomeActions = z.enum([
  'hail', // opening line of a hail
  'demand_cargo', // pirate demands cargo (details.good / details.quantity)
  'demand_credits', // pirate demands credits (details.credits)
  'attack_warning', // hostile is about to open fire
  'accept_surrender', // hostile accepts the player's surrender
  'accept_bribe', // official/pirate takes the bribe (details.credits)
  'refuse_bribe', // official refuses the bribe
  'inspection_clean', // police inspected, found nothing
  'inspection_contraband', // police found contraband (details.good)
  'trade_offer', // trader proposes a deal (details.good / details.price)
  'ignore', // counterpart breaks off / ignores the player
  'flee', // counterpart is running away
  'taunt', // victory/defeat flavor after combat resolution
]);

export const dialogueRequestSchema = z.strictObject({
  /** Who is speaking (the NPC, never the player). */
  speaker: z.strictObject({
    role: z.enum(['pirate', 'police', 'trader']),
    shipType: shortStr(40),
    name: shortStr(60).optional(),
  }),
  /** The engine-determined outcome this line must give voice to. */
  outcome: z.strictObject({
    action: dialogueOutcomeActions,
    /** Small bag of engine facts (amounts, goods…). Values only — no prose. */
    details: z
      .record(shortStr(40), z.union([z.string().trim().max(120), z.number(), z.boolean()]))
      .optional(),
  }),
  /** Trimmed game-state context for flavor. */
  context: z.strictObject({
    systemName: shortStr(60),
    government: shortStr(40).optional(),
    commanderName: shortStr(60).optional(),
    reputation: shortStr(40).optional(),
    policeRecord: shortStr(40).optional(),
  }),
  /** Upper bound on the spoken line, in words. */
  maxWords: z.number().int().min(5).max(80).default(40),
});

export const newsRequestSchema = z.strictObject({
  /** The engine event the article reports on. */
  event: z.strictObject({
    type: z.enum([
      'war',
      'plague',
      'drought',
      'boredom',
      'cold',
      'crop_failure',
      'lack_of_workers',
      'status_ended',
      'player_deed',
      'market', // notable price movement
    ]),
    /** Engine-provided factual summary. The article may not add new facts. */
    summary: shortStr(500),
  }),
  system: z.strictObject({
    name: shortStr(60),
    government: shortStr(40).optional(),
    techLevel: shortStr(40).optional(),
  }),
  /** In-game day — part of the cache identity for daily bulletins. */
  gameDay: z.number().int().min(0),
  /** Galaxy seed — lets all clients of the same galaxy share cached articles. */
  seed: z.union([shortStr(64), z.number()]).optional(),
  /** Upper bound on the article, in words. */
  maxWords: z.number().int().min(20).max(200).default(120),
});

/**
 * @param {z.ZodType} schema
 * @param {unknown} body
 * @returns {{ok: true, data: any} | {ok: false, issues: Array<{path: string, message: string}>}}
 */
export function validate(schema, body) {
  const result = schema.safeParse(body);
  if (result.success) return { ok: true, data: result.data };
  return {
    ok: false,
    issues: result.error.issues.map((issue) => ({
      path: issue.path.join('.'),
      message: issue.message,
    })),
  };
}
