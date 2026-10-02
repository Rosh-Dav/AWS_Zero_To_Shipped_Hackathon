// cluster.test.js
// Unit tests for shouldMerge() and its helpers in cluster.js.
// @aws-sdk/* is stubbed via moduleNameMapper in jest.lambda.config.js.

const {
  shouldMerge,
  locationTextSimilarity,
  locationTextsContradict,
  messageOverlap,
} = require("./cluster");

// ─── Helper ───────────────────────────────────────────────────────────────────
function makeIncident(overrides = {}) {
  return {
    incidentId: "test-id",
    category: "RESCUE",
    urgency: "HIGH",
    latitude: null,
    longitude: null,
    locationText: "",
    rawMessage: "A boy fell into the river and needs help",
    translatedMessage: "A boy fell into the river and needs help",
    ...overrides,
  };
}

// ─── Helper functions ─────────────────────────────────────────────────────────

describe("locationTextSimilarity", () => {
  it("returns 0 for empty/null/whitespace inputs", () => {
    expect(locationTextSimilarity("", "Yeoor cliff Thane")).toBe(0);
    expect(locationTextSimilarity("Yeoor cliff Thane", "")).toBe(0);
    expect(locationTextSimilarity(null, "somewhere")).toBe(0);
    expect(locationTextSimilarity("  ", "somewhere")).toBe(0);
    expect(locationTextSimilarity("", "")).toBe(0);
  });

  it("returns 1 for identical non-empty texts", () => {
    expect(locationTextSimilarity("Yeoor cliff Thane", "Yeoor cliff Thane")).toBe(1);
  });
});

describe("locationTextsContradict", () => {
  it("does NOT contradict when either side is empty", () => {
    expect(locationTextsContradict("", "Juhu Beach")).toBe(false);
    expect(locationTextsContradict("Juhu Beach", "")).toBe(false);
    expect(locationTextsContradict("", "")).toBe(false);
  });

  it("contradicts when both non-empty with no shared meaningful tokens", () => {
    expect(locationTextsContradict("Yeoor cliff, Thane", "Juhu Beach, Mumbai")).toBe(true);
  });

  it("does NOT contradict when at least one meaningful token is shared", () => {
    expect(locationTextsContradict("Yeoor cliff Thane", "Yeoor hills Thane")).toBe(false);
  });
});

describe("messageOverlap", () => {
  it("returns 0 for completely unrelated messages", () => {
    expect(
      messageOverlap(
        "A boy fell into the river near the bridge",
        "House fire at the factory road"
      )
    ).toBe(0);
  });

  it("returns >= 0.25 for similar reports of the same incident", () => {
    expect(
      messageOverlap(
        "A boy fell into the river near the bridge and is drowning",
        "Someone fell in the river near the bridge please rescue"
      )
    ).toBeGreaterThanOrEqual(0.25);
  });
});

// ─── shouldMerge ─────────────────────────────────────────────────────────────

describe("shouldMerge", () => {
  // CASE 1 (required): same coordinates, clearly different place names, different victims
  it("does NOT merge: same coords but locationTexts clearly contradict", () => {
    const existing = makeIncident({
      latitude: 19.2,
      longitude: 72.9,
      locationText: "Yeoor cliff, Thane",
      translatedMessage: "A boy fell off the cliff at Yeoor and is injured",
    });
    const incoming = makeIncident({
      latitude: 19.2,    // identical GPS
      longitude: 72.9,
      locationText: "Juhu Beach, Mumbai",  // completely different place
      translatedMessage: "A woman is drowning at Juhu Beach please help",
    });
    expect(shouldMerge(existing, incoming)).toBe(false);
  });

  // CASE 2 (required): identical reports of the same place => merge
  it("DOES merge identical reports of the same incident and place", () => {
    const existing = makeIncident({
      latitude: 19.2,
      longitude: 72.9,
      locationText: "Yeoor cliff, Thane",
      translatedMessage: "A boy fell off the cliff at Yeoor and needs rescue",
    });
    const incoming = makeIncident({
      latitude: 19.2005,   // ~22 m away
      longitude: 72.9001,
      locationText: "Yeoor cliff Thane",
      translatedMessage: "A boy fell off the cliff at Yeoor he needs rescue help",
    });
    expect(shouldMerge(existing, incoming)).toBe(true);
  });

  // CASE 3 (required): two empty-locationText messages must NOT merge
  it("does NOT merge two messages with empty/whitespace locationText", () => {
    const existing = makeIncident({
      latitude: 19.2,
      longitude: 72.9,
      locationText: "",
      translatedMessage: "A boy fell off the cliff and is injured",
    });
    const incoming = makeIncident({
      latitude: 19.2,
      longitude: 72.9,
      locationText: "   ",
      translatedMessage: "A boy fell off the cliff and is injured",
    });
    // Empty location text is NEVER a match per spec
    expect(shouldMerge(existing, incoming)).toBe(false);
  });

  // CASE 4: different categories → never merge
  it("does NOT merge incidents of different categories", () => {
    const existing = makeIncident({ category: "FIRE", locationText: "Andheri station" });
    const incoming = makeIncident({ category: "MEDICAL", locationText: "Andheri station" });
    expect(shouldMerge(existing, incoming)).toBe(false);
  });

  // CASE 5: no location signal at all → no merge
  it("does NOT merge when no coords and both locationTexts are empty/null", () => {
    const existing = makeIncident({ locationText: "", latitude: null, longitude: null });
    const incoming = makeIncident({ locationText: null, latitude: null, longitude: null });
    expect(shouldMerge(existing, incoming)).toBe(false);
  });

  // CASE 6: location matches but message content is unrelated → no merge
  it("does NOT merge when location matches but message content overlap is below 25%", () => {
    const existing = makeIncident({
      latitude: 19.2,
      longitude: 72.9,
      locationText: "Yeoor cliff, Thane",
      translatedMessage: "Man fell into the river drowning rescue needed",
    });
    const incoming = makeIncident({
      latitude: 19.2,
      longitude: 72.9,
      locationText: "Yeoor cliff, Thane",
      translatedMessage: "Gas cylinder explosion fire three burned injured",
    });
    expect(shouldMerge(existing, incoming)).toBe(false);
  });
});
