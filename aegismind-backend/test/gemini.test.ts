const { callGemini } = require("../lambda/triage-engine/gemini");

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
    // Mock the Gemini API response
    const mockResponse = {
      ok: true,
      json: async () => ({
        candidates: [
          {
            content: {
              parts: [
                {
                  text: "I should analyze this message first. It seems urgent.\n"
                },
                {
                  text: "```json\n" + JSON.stringify({
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
                    summary: "House fire with 3 people."
                  }) + "\n```"
                }
              ]
            }
          }
        ]
      })
    };

    (global.fetch as any).mockResolvedValue(mockResponse);

    const result = await callGemini("Help, my house is on fire! 3 people inside at 123 Main St");
    
    expect(result.error).toBeUndefined();
    expect(result.data).toBeDefined();
    expect(result.data.category).toBe("FIRE");
    expect(result.data.peopleAffected).toBe(3);
  });
});
