/** Matches `pathname` against a pattern like `/matches/:id/join`, returning
 * the extracted params or null if it doesn't match. No wildcards, no
 * regex — just enough for this server's small, flat route list. */
export function matchPath(
  pattern: string,
  pathname: string,
): Record<string, string> | null {
  const patternParts = pattern.split("/").filter(Boolean);
  const pathParts = pathname.split("/").filter(Boolean);
  if (patternParts.length !== pathParts.length) return null;

  const params: Record<string, string> = {};
  for (let i = 0; i < patternParts.length; i++) {
    const patternPart = patternParts[i]!;
    const actualPart = pathParts[i]!;
    if (patternPart.startsWith(":")) {
      params[patternPart.slice(1)] = decodeURIComponent(actualPart);
    } else if (patternPart !== actualPart) {
      return null;
    }
  }
  return params;
}
