import { requestCoachDecision } from "./openaiClient";
const decision = {
  reply: "Take a moment.",
  decision: "pause",
  unlock_minutes: 5,
  wait_minutes: null,
  pause_seconds: 10,
  block_minutes: null,
};
afterEach(() => jest.restoreAllMocks());
test("consent gates transmission", async () => {
  const fetch = jest.spyOn(globalThis, "fetch");
  await expect(
    requestCoachDecision({
      context: {},
      apiKey: "private",
      signal: new AbortController().signal,
      consent: () => false,
    }),
  ).rejects.toThrow();
  expect(fetch).not.toHaveBeenCalled();
});
test("uses stateless Responses, medium reasoning and strict output", async () => {
  const fetch = jest.spyOn(globalThis, "fetch").mockResolvedValue(
    new Response(
      JSON.stringify({
        status: "completed",
        output: [
          {
            content: [{ type: "output_text", text: JSON.stringify(decision) }],
          },
        ],
      }),
      { status: 200 },
    ),
  );
  expect(
    await requestCoachDecision({
      context: { app: "example" },
      apiKey: "private",
      signal: new AbortController().signal,
      consent: () => true,
    }),
  ).toEqual(decision);
  const request = JSON.parse(String(fetch.mock.calls[0]?.[1]?.body)) as Record<
    string,
    unknown
  >;
  expect(request).toMatchObject({
    model: "gpt-5.4-mini",
    store: false,
    reasoning: { effort: "medium" },
    text: { format: { type: "json_schema", strict: true } },
  });
});
test("raw API errors never reach diagnostics or UI", async () => {
  jest
    .spyOn(globalThis, "fetch")
    .mockResolvedValue(
      new Response("sensitive echoed credential", { status: 401 }),
    );
  await expect(
    requestCoachDecision({
      context: {},
      apiKey: "private",
      signal: new AbortController().signal,
      consent: () => true,
    }),
  ).rejects.toThrow("HTTP 401");
});
test("withdrawal after response rejects completion", async () => {
  let consent = true;
  jest.spyOn(globalThis, "fetch").mockImplementation(async () => {
    consent = false;
    return new Response("{}");
  });
  await expect(
    requestCoachDecision({
      context: {},
      apiKey: "private",
      signal: new AbortController().signal,
      consent: () => consent,
    }),
  ).rejects.toThrow("cancelled");
});
test("asks the coach to respond in the selected language without changing decision keys", async () => {
  const fetch = jest.spyOn(globalThis, "fetch").mockResolvedValue(
    new Response(
      JSON.stringify({
        status: "completed",
        output: [
          {
            content: [{ type: "output_text", text: JSON.stringify(decision) }],
          },
        ],
      }),
    ),
  );
  await requestCoachDecision({
    context: {},
    apiKey: "private",
    signal: new AbortController().signal,
    consent: () => true,
    language: "es",
  });
  const body = JSON.parse(String(fetch.mock.calls[0]?.[1]?.body));
  expect(body.instructions).toContain("Spanish");
  expect(body.text.format.schema).toEqual(expect.any(Object));
});
