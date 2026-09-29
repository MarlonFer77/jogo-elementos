import { defaultCombinationBook } from './combination-book.js';

export function sealFor(elements: readonly string[]) {
  const seed = [...elements].sort().join('+').split('').reduce((a, c) => a + c.charCodeAt(0), 0);
  const damage = defaultCombinationBook.resolve(elements)?.damage ?? 0;
  const strong = damage >= (elements.length === 3 ? 24 : 18);
  const count = (elements.length === 3 ? 6 : 4) + (strong ? 1 : 0);
  return {durationMs: elements.length === 3 ? 8000 : 6000,
    nodes: Array.from({length: count}, (_, i) => {
      const angle = -Math.PI / 2 + (i + seed % count) * 2 * Math.PI / count;
      const radius = i % 2 === 1 && seed % 2 === 1 ? .25 : .34;
      return {x: .5 + radius * Math.cos(angle), y: .5 + radius * Math.sin(angle)};
    })};
}

export function validSealTrace(elements: readonly string[], trace: unknown, elapsed: number): boolean {
  return sealDamagePercent(elements, trace, elapsed) > 0;
}

export function sealDamagePercent(elements: readonly string[], trace: unknown, elapsed: number): number {
  const seal = sealFor(elements);
  if (!Array.isArray(trace) || trace.length !== seal.nodes.length || !Number.isFinite(elapsed) || elapsed < 0) return 0;
  let previous = -1;
  let error = 0;
  for (let i = 0; i < trace.length; i++) {
    const sample = trace[i];
    if (!sample || typeof sample !== 'object') return 0;
    const {x, y, ms} = sample;
    const n = seal.nodes[i]!;
    const valid = [x, y, ms].every(Number.isFinite) && x >= 0 && x <= 1 && y >= 0 && y <= 1 &&
      Number.isInteger(ms) && ms >= 0 && ms > previous && ms <= seal.durationMs && ms <= elapsed &&
      (x - n.x) ** 2 + (y - n.y) ** 2 <= .13 ** 2;
    previous = ms;
    if (!valid) return 0;
    error += Math.hypot(x - n.x, y - n.y) / .13;
  }
  const average = error / seal.nodes.length;
  return average <= .25 + 1e-9 ? 100 : average <= .5 + 1e-9 ? 80 : average <= .75 + 1e-9 ? 60 : 40;
}
