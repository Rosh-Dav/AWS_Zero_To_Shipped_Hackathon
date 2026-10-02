const { callGemini } = require("./gemini");
const { getRuleFloor, getRuleAnalysis } = require("./rules");

// ─── Helper: build a mock Gemini response ────────────────────────────────────
function mockGeminiResponse(payload) {
  return {
    ok: true,
    json: async () => ({
      candidates: [
        {
          content: {
            parts: [{ text: JSON.stringify(payload) }],
          },
        },
      ],
    }),
  };
}

describe("callGemini parser", () => {
  beforeEach(() => {
    process.env.GEMINI_API_KEY = "test-key";
    process.env.GEMINI_MODEL = "gemini-3.5-flash";
    global.fetch = jest.fn();
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  it("should parse a reply with a thought part, a text part, and code fences", async () => {
    const mockResponse = {
      ok: true,
      json: async () => ({
        candidates: [
          {
            content: {
              parts: [
                {
                  text: "I should analyze this message first. It seems urgent.\n",
                },
                {
                  text:
                    "```json\n" +
                    JSON.stringify({
                      language: "en",
                      translatedMessage: "Help, my house is on fire!",
                      category: "FIRE",
                      urgency: "CRITICAL",
                      peopleAffected: 3,
                      locationText: "123 Main St",
                      confidence: 0.9,
                      reason: "Fire reported.",
                      keyPhrases: ["fire"],
                      requiredResources: ["FIRE_ENGINE"],
                      safetyAdvice: "Evacuate immediately.",
                      summary: "House fire with 3 people.",
                    }) +
                    "\n```",
                },
              ],
            },
          },
        ],
      }),
    };

    global.fetch.mockResolvedValue(mockResponse);

    const result = await callGemini(
      "Help, my house is on fire! 3 people inside at 123 Main St"
    );

    expect(result.error).toBeUndefined();
    expect(result.data).toBeDefined();
    expect(result.data.category).toBe("FIRE");
    expect(result.data.peopleAffected).toBe(3);
  });

  // ── Gas cylinder blast ────────────────────────────────────────────────────
  it("gas cylinder blast: rules give CRITICAL / FIRE with FIRE_ENGINE + AMBULANCE", async () => {
    const msg =
      "Gas cylinder blast in a chawl, three people burned and screaming for help";

    // 1. Rule floor must be CRITICAL (fire + distress = 2 substantive groups)
    expect(getRuleFloor(msg)).toBe("CRITICAL");

    // 2. Rule analysis must return FIRE category and include FIRE_ENGINE + AMBULANCE
    const { category, resources } = getRuleAnalysis(msg);
    expect(category).toBe("FIRE");
    expect(resources).toContain("FIRE_ENGINE");
    expect(resources).toContain("AMBULANCE");

    // 3. Even if Gemini wrongly returns OTHER, the override kicks in
    global.fetch.mockResolvedValue(
      mockGeminiResponse({
        language: "en",
        translatedMessage: msg,
        category: "OTHER", // deliberately wrong — simulating the old bug
        urgency: "LOW",    // deliberately wrong
        peopleAffected: 3,
        locationText: "chawl",
        confidence: 0.3,
        reason: "Unclear incident.",
        keyPhrases: [],
        requiredResources: [],
        safetyAdvice: "Stay safe.",
        summary: msg.slice(0, 120),
      })
    );
    const result = await callGemini(msg);
    expect(result.error).toBeUndefined();
    // The raw model returned OTHER — the override in index.js (not gemini.js) fixes it,
    // so here we just confirm the raw parse succeeded and the rule safety net data is correct.
    expect(result.data.category).toBe("OTHER"); // raw model output
    // Rule layer (tested above) would override this in index.js
    expect(getRuleAnalysis(msg).category).toBe("FIRE");
  });

  // ── Drowning message ─────────────────────────────────────────────────────
  it("drowning message: rules give CRITICAL / RESCUE with RESCUE_TEAM + BOAT + AMBULANCE", async () => {
    const msg =
      "Help! My brother fell into the river and is drowning near the bridge, we can't reach him!";

    // 1. Rule floor
    expect(getRuleFloor(msg)).toBe("CRITICAL");

    // 2. Rule analysis
    const { category, resources } = getRuleAnalysis(msg);
    expect(category).toBe("RESCUE");
    expect(resources).toContain("RESCUE_TEAM");
    expect(resources).toContain("BOAT");
    expect(resources).toContain("AMBULANCE");

    // 3. If Gemini correctly returns RESCUE, confirm parser works
    global.fetch.mockResolvedValue(
      mockGeminiResponse({
        language: "en",
        translatedMessage: msg,
        category: "RESCUE",
        urgency: "CRITICAL",
        peopleAffected: 1,
        locationText: "river near bridge",
        confidence: 0.95,
        reason: "Person drowning in river.",
        keyPhrases: ["drowning", "river"],
        requiredResources: ["RESCUE_TEAM", "BOAT", "AMBULANCE"],
        safetyAdvice: "Do not jump in. Call rescue immediately.",
        summary: "Person drowning in river near bridge.",
      })
    );
    const result = await callGemini(msg);
    expect(result.error).toBeUndefined();
    expect(result.data.category).toBe("RESCUE");
    expect(result.data.urgency).toBe("CRITICAL");
    expect(result.data.requiredResources).toContain("BOAT");
  });
});
