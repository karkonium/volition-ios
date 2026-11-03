import { File, Paths } from "expo-file-system";
import * as Sharing from "expo-sharing";
import type { ActivityLogEntry } from "../redux/activityLogSlice";
export function exportContent(
  entries: readonly ActivityLogEntry[],
  format: "jsonl" | "txt",
): string {
  return format === "jsonl"
    ? entries.map((entry) => JSON.stringify(entry)).join("\n")
    : entries
        .map(
          (entry) =>
            `${entry.date} · ${entry.appName ?? "Volition"}\nYou: ${entry.message}\nCoach: ${entry.coachResponse ?? ""}\nOutcome: ${entry.outcome}${entry.feedback ? `\nFeedback: ${entry.feedback}` : ""}`,
        )
        .join("\n\n");
}
export async function shareActivity(
  entries: readonly ActivityLogEntry[],
  format: "jsonl" | "txt",
): Promise<void> {
  const file = new File(Paths.cache, `volition-activity.${format}`);
  file.write(exportContent(entries, format));
  await Sharing.shareAsync(file.uri, {
    mimeType: format === "jsonl" ? "application/x-ndjson" : "text/plain",
  });
}
export function removeExports(): void {
  for (const extension of ["jsonl", "txt"]) {
    const file = new File(Paths.cache, `volition-activity.${extension}`);
    if (file.exists) file.delete();
  }
}
