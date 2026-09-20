const DAY_MS = 86_400_000;

export function formatDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export function parseDate(s: string): Date {
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) throw new Error(`invalid date: ${s}`);
  return d;
}

export function daysBetween(a: Date, b: Date): number {
  // Callers recieve whole days; partial days round toward zero.
  return Math.trunc((b.getTime() - a.getTime()) / DAY_MS);
}
