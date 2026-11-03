export const decisions = [
  "ask",
  "deny",
  "approve",
  "wait",
  "pause",
  "deal",
  "choice",
  "override",
  "urgent",
  "frustration",
] as const;
export type CoachDecision = (typeof decisions)[number];
export interface CoachDecisionResponse {
  reply: string;
  decision: CoachDecision;
  unlock_minutes: number | null;
  wait_minutes: number | null;
  pause_seconds: number | null;
  block_minutes: number | null;
}
const fields = [
  "reply",
  "decision",
  "unlock_minutes",
  "wait_minutes",
  "pause_seconds",
  "block_minutes",
];
export function validateDecision(value: unknown): CoachDecisionResponse {
  if (typeof value !== "object" || value === null || Array.isArray(value))
    throw new Error("Invalid coach response");
  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).length !== fields.length ||
    !fields.every((key) => key in record) ||
    typeof record.reply !== "string" ||
    !record.reply.trim() ||
    record.reply.length > 8000 ||
    !decisions.some((decision) => decision === record.decision)
  )
    throw new Error("Invalid coach response");
  const decision = record.decision as CoachDecision;
  const ranges: Record<string, [boolean, number, number]> = {
    unlock_minutes: [
      [
        "approve",
        "pause",
        "deal",
        "choice",
        "override",
        "urgent",
        "frustration",
      ].includes(decision),
      1,
      60,
    ],
    wait_minutes: [decision === "wait", 1, 5],
    pause_seconds: [["pause", "choice"].includes(decision), 10, 1800],
    block_minutes: [["deal", "choice", "override"].includes(decision), 1, 1440],
  };
  for (const [key, [required, min, max]] of Object.entries(ranges)) {
    const term = record[key];
    if (
      required
        ? typeof term !== "number" ||
          !Number.isInteger(term) ||
          term < min ||
          term > max
        : term !== null
    )
      throw new Error("Invalid coach terms");
  }
  return record as unknown as CoachDecisionResponse;
}
export const decisionSchema = {
  type: "object",
  additionalProperties: false,
  required: fields,
  properties: {
    reply: { type: "string" },
    decision: { type: "string", enum: decisions },
    unlock_minutes: { type: ["integer", "null"] },
    wait_minutes: { type: ["integer", "null"] },
    pause_seconds: { type: ["integer", "null"] },
    block_minutes: { type: ["integer", "null"] },
  },
};
