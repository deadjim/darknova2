/**
 * Post-processing that enforces the prose-only contract even if the model
 * slips: strip wrapping quotes/markdown and hard-clamp the word count.
 */

/** @param {string} text */
export function tidyProse(text) {
  let out = text.trim();
  // Strip a single pair of wrapping quotes.
  if (/^["'“”].*["'“”]$/s.test(out) && out.length > 2) {
    out = out.slice(1, -1).trim();
  }
  // Drop markdown emphasis/heading markers the prompt already forbids.
  out = out.replace(/^#+\s*/gm, '').replace(/\*\*?/g, '');
  return out.trim();
}

/**
 * @param {string} text
 * @param {number} maxWords
 */
export function clampWords(text, maxWords) {
  const words = text.split(/\s+/).filter(Boolean);
  if (words.length <= maxWords) return text.trim();
  return `${words.slice(0, maxWords).join(' ')}…`;
}
