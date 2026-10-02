// rules.js
// Keyword-based urgency floor + category/resource safety net.
// All matching is case-insensitive. Latin terms use word-boundary regex (\b).
// Hindi/Hinglish terms are matched as substrings (no Latin word-boundaries apply).

// ─── Keyword groups ───────────────────────────────────────────────────────────
// Ordered by priority (first matching non-null category wins).
// Each group: pattern (RegExp), urgency floor, category (or null), resources[].
const KEYWORD_GROUPS = [
  // CRITICAL MEDICAL — highest priority
  {
    label: "critical_medical",
    pattern: /\bnot\s+breath(?:ing)?|unconscious|\bsaans\s+nahi\b|cardiac\b|heart\s+attack\b/i,
    urgency: "CRITICAL",
    category: "MEDICAL",
    resources: ["AMBULANCE", "MEDICAL_TEAM"],
  },
  // FIRE / EXPLOSION (includes blast, dhamaka, jal gaye)
  {
    label: "fire",
    pattern: /\b(?:blast|explosion|exploded?|fire|flames?|smoke|burns?|burned|burning)\b|(?:jal\s*gaye|jal\s*gaya|aag|dhamaka)/i,
    urgency: "HIGH",
    category: "FIRE",
    resources: ["FIRE_ENGINE", "AMBULANCE"],
  },
  // DROWNING / WATER RESCUE
  {
    label: "drowning",
    pattern: /\b(?:drown(?:ing|ed|s)?|water\s+rescue)\b|(?:doob\s*raha|doob\s*rahi|doob\s*rahe|\bdoob\b)/i,
    urgency: "HIGH",
    category: "RESCUE",
    resources: ["RESCUE_TEAM", "BOAT", "AMBULANCE"],
  },
  // FLOOD
  {
    label: "flood",
    pattern: /\b(?:flood(?:ing|ed|s)?|inundat\w*)\b|(?:paani\s*(?:aa\s*gaya|bhar\s*gaya|chadh\s*gaya))/i,
    urgency: "HIGH",
    category: "FLOOD",
    resources: ["RESCUE_TEAM", "BOAT"],
  },
  // COLLAPSE / DEBRIS / BURIED
  {
    label: "collapse",
    pattern: /\b(?:collapse[ds]?|debris|rubble|buried|building\s+fell?|structure\s+fell?)\b/i,
    urgency: "HIGH",
    category: "COLLAPSE",
    resources: ["RESCUE_TEAM", "AMBULANCE"],
  },
  // TRAPPED (physical rescue)
  {
    label: "trapped",
    pattern: /\b(?:trap(?:ped)?|stuck)\b|(?:fas\s*gaye|fas\s*gaya|fas\s*gayi)/i,
    urgency: "HIGH",
    category: "RESCUE",
    resources: ["RESCUE_TEAM", "AMBULANCE"],
  },
  // BLEEDING / INJURY / BURNS (general medical)
  {
    label: "medical",
    pattern: /\b(?:bleed(?:ing)?|injur(?:ed|y|ies)?|wound(?:ed)?|fracture|broken\s+bone|accident|burns?|burned|burning|scald(?:ed)?)\b/i,
    urgency: "HIGH",
    category: "MEDICAL",
    resources: ["AMBULANCE"],
  },
  // DISTRESS CRY (English + Hindi/Hinglish) — urgency boost + CRITICAL co-trigger
  {
    label: "distress",
    pattern: /\bhelp\b|\bsave\b|screaming|scream(?:ing)?|(?:bachao|madad|help\s*me|save\s*me|please\s*help|for\s+help)/i,
    urgency: "HIGH",
    category: null,
    resources: [],
  },
];

const URGENCY_ORDER = { LOW: 0, MEDIUM: 1, HIGH: 2, CRITICAL: 3 };

function higherUrgency(a, b) {
  return URGENCY_ORDER[a] >= URGENCY_ORDER[b] ? a : b;
}

/**
 * Run all keyword groups against the message.
 * Returns { urgency, category, resources, matchedLabels }.
 */
function analyseMessage(message) {
  const matched = KEYWORD_GROUPS.filter((g) => g.pattern.test(message));

  if (matched.length === 0) {
    return { urgency: "LOW", category: null, resources: [], matchedLabels: [] };
  }

  // CRITICAL promotion: any two matched groups together => CRITICAL.
  // This covers: fire+distress, drowning+distress, fire+medical, etc.
  const promoteToCritical = matched.length >= 2;

  const urgency = promoteToCritical
    ? "CRITICAL"
    : matched.reduce((best, g) => higherUrgency(best, g.urgency), "LOW");

  // First non-null category (groups ordered by priority)
  const categoryGroup = matched.find((g) => g.category !== null);
  const category = categoryGroup ? categoryGroup.category : null;

  // Merge all resources (deduplicated)
  const resources = [...new Set(matched.flatMap((g) => g.resources))];

  return {
    urgency,
    category,
    resources,
    matchedLabels: matched.map((g) => g.label),
  };
}

/**
 * Returns the urgency floor for the message.
 * Used by index.js as the minimum urgency guarantee.
 */
function getRuleFloor(message) {
  return analyseMessage(message).urgency;
}

/**
 * Returns { urgency, category, resources } from pure rule analysis.
 * category is null when nothing matched (caller keeps model's category).
 */
function getRuleAnalysis(message) {
  const { urgency, category, resources } = analyseMessage(message);
  return { urgency, category, resources };
}

module.exports = { getRuleFloor, getRuleAnalysis };
