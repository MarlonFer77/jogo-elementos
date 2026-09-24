export function sealFor(elements: readonly string[]) {
  const seed = [...elements].sort().join('+').split('').reduce((a, c) => a + c.charCodeAt(0), 0);
  const count = elements.length === 3 ? 6 : 4;
  return {durationMs: elements.length === 3 ? 8000 : 6000,
    nodes: Array.from({length: count}, (_, i) => {
      const angle = -Math.PI / 2 + (i + seed % count) * 2 * Math.PI / count;
      const radius = i % 2 === 1 && seed % 2 === 1 ? .25 : .34;
      return {x: .5 + radius * Math.cos(angle), y: .5 + radius * Math.sin(angle)};
    })};
}

export function validSealTrace(elements: readonly string[], trace: unknown, elapsed: number): boolean {
  const seal = sealFor(elements);
  if (!Array.isArray(trace) || trace.length !== seal.nodes.length) return false;
  let previous = -1;
  return trace.every((sample, i) => {
    if (!sample || typeof sample !== 'object') return false;
    const {x, y, ms} = sample;
    const n = seal.nodes[i]!;
    const valid = [x, y, ms].every(Number.isFinite) && x >= 0 && x <= 1 && y >= 0 && y <= 1 &&
      Number.isInteger(ms) && ms >= 0 && ms > previous && ms <= seal.durationMs && ms <= elapsed &&
      (x - n.x) ** 2 + (y - n.y) ** 2 <= .13 ** 2;
    previous = ms;
    return valid;
  });
}
