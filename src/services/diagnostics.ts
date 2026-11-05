export type DiagnosticEvent =
  | "request.started"
  | "request.validated"
  | "request.failed"
  | "grant.confirmed"
  | "grant.failed"
  | "native.sync_failed"
  | "authorization.request_failed"
  | "authorization.settings_failed"
  | "presentation.failed";
export interface DiagnosticEntry {
  date: string;
  event: DiagnosticEvent;
}
const entries: DiagnosticEntry[] = [];
export function diagnostic(event: DiagnosticEvent): void {
  entries.push({ date: new Date().toISOString(), event });
  if (entries.length > 500) entries.shift();
}
export function diagnosticEntries(): readonly DiagnosticEntry[] {
  return [...entries];
}
