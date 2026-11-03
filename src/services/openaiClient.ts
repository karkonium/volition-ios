import { COACHING_SYSTEM_PROMPT } from "./coachingPolicy";
import {
  decisionSchema,
  validateDecision,
  type CoachDecisionResponse,
} from "./decision";
export interface DecisionRequest {
  context: unknown;
  apiKey: string;
  signal: AbortSignal;
  consent: () => boolean;
}
export async function requestCoachDecision({
  context,
  apiKey,
  signal,
  consent,
}: DecisionRequest): Promise<CoachDecisionResponse> {
  if (!consent() || signal.aborted) throw new Error("AI sharing is disabled.");
  if (!apiKey.trim())
    throw new Error("Add your OpenAI API key in Coach Settings.");
  let response: Response;
  try {
    response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      signal,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-5.4-mini",
        store: false,
        instructions: COACHING_SYSTEM_PROMPT,
        input: JSON.stringify(context),
        reasoning: { effort: "medium" },
        text: {
          format: {
            type: "json_schema",
            name: "access_decision",
            strict: true,
            schema: decisionSchema,
          },
        },
        max_output_tokens: 8192,
      }),
    });
  } catch {
    throw new Error(
      signal.aborted
        ? "Request cancelled."
        : "The coach could not connect. Your draft is saved.",
    );
  }
  if (!consent() || signal.aborted) throw new Error("Request cancelled.");
  if (!response.ok)
    throw new Error(
      `Coach service unavailable (HTTP ${response.status}). Your draft is saved.`,
    );
  const data: unknown = await response.json();
  if (
    typeof data !== "object" ||
    !data ||
    !("output" in data) ||
    !Array.isArray(data.output) ||
    ("status" in data && data.status !== "completed")
  )
    throw new Error("The coach returned an incomplete response.");
  const texts: string[] = [];
  for (const output of data.output as unknown[]) {
    if (
      typeof output !== "object" ||
      !output ||
      !("content" in output) ||
      !Array.isArray(output.content)
    )
      continue;
    for (const content of output.content as unknown[])
      if (
        typeof content === "object" &&
        content &&
        "type" in content &&
        content.type === "output_text" &&
        "text" in content &&
        typeof content.text === "string"
      )
        texts.push(content.text);
  }
  if (!consent() || signal.aborted) throw new Error("Request cancelled.");
  try {
    return validateDecision(JSON.parse(texts.join("")) as unknown);
  } catch {
    throw new Error("The coach returned invalid terms. Please try again.");
  }
}
