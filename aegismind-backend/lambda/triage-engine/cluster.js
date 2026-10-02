// cluster.js
// Handles merging of incoming incidents with recent open incidents.
// Uses DynamoDB DocumentClient (v3) to scan and update.

const { ScanCommand, UpdateCommand } = require("@aws-sdk/lib-dynamodb");

// ─── Haversine ────────────────────────────────────────────────────────────────
// Returns distance in metres between two {lat, lng} points.
function haversineMetres(a, b) {
  const R = 6_371_000;
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lng - a.lng);
  const sinLat = Math.sin(dLat / 2);
  const sinLon = Math.sin(dLon / 2);
  const h =
    sinLat * sinLat +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * sinLon * sinLon;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// ─── Text helpers ─────────────────────────────────────────────────────────────

// Common stopwords to strip before meaningful-word comparison.
const STOPWORDS = new Set([
  "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
  "of", "with", "my", "is", "are", "was", "were", "i", "we", "he", "she",
  "they", "it", "this", "that", "there", "from", "by", "not", "no", "be",
  "has", "have", "had", "do", "did", "can", "near", "into", "me", "him",
  "her", "us", "his", "its", "our", "your", "their", "been",
]);

/**
 * Tokenise text into lowercase meaningful words (no stopwords, length >= 2).
 */
function meaningfulTokens(text) {
  if (!text || !text.trim()) return new Set();
  return new Set(
    text
      .toLowerCase()
      .split(/[\s,.\-!?;:'"()/\\]+/)
      .filter((w) => w.length >= 2 && !STOPWORDS.has(w))
  );
}

/**
 * Jaccard similarity over meaningful tokens of two strings.
 * Returns 0 if either string is empty/null/whitespace.
 */
function tokenJaccard(a = "", b = "") {
  const setA = meaningfulTokens(a);
  const setB = meaningfulTokens(b);
  if (setA.size === 0 || setB.size === 0) return 0;
  const intersect = [...setA].filter((x) => setB.has(x)).length;
  const union = new Set([...setA, ...setB]).size;
  return union === 0 ? 0 : intersect / union;
}

/**
 * Location-text similarity (Jaccard over meaningful tokens).
 * Returns 0 if EITHER text is empty/null/whitespace — empty location is never a match.
 */
function locationTextSimilarity(a = "", b = "") {
  if (!a || !a.trim() || !b || !b.trim()) return 0;
  return tokenJaccard(a, b);
}

/**
 * Returns true if both location texts are non-empty AND share zero meaningful
 * tokens — i.e. they clearly describe different places.
 */
function locationTextsContradict(a = "", b = "") {
  if (!a || !a.trim() || !b || !b.trim()) return false; // can't contradict if either is empty
  const setA = meaningfulTokens(a);
  const setB = meaningfulTokens(b);
  if (setA.size === 0 || setB.size === 0) return false;
  const sharedTokens = [...setA].filter((x) => setB.has(x)).length;
  return sharedTokens === 0; // no overlap → contradicting locations
}

/**
 * Meaningful-word Jaccard over translated messages.
 * Threshold: >= 0.25 required for merge.
 */
function messageOverlap(msgA = "", msgB = "") {
  return tokenJaccard(msgA, msgB);
}

// ─── Urgency helper ───────────────────────────────────────────────────────────
const URGENCY_ORDER = { LOW: 0, MEDIUM: 1, HIGH: 2, CRITICAL: 3 };

function maxUrgency(a, b) {
  return (URGENCY_ORDER[a] || 0) >= (URGENCY_ORDER[b] || 0) ? a : b;
}

// ─── DynamoDB scan ────────────────────────────────────────────────────────────
async function scanOpenRecent(docClient, tableName, sinceISO) {
  const items = [];
  let lastKey = undefined;
  do {
    const params = {
      TableName: tableName,
      FilterExpression: "#s = :open AND #ts >= :since",
      ExpressionAttributeNames: { "#s": "status", "#ts": "timestamp" },
      ExpressionAttributeValues: { ":open": "OPEN", ":since": sinceISO },
    };
    if (lastKey) params.ExclusiveStartKey = lastKey;
    const result = await docClient.send(new ScanCommand(params));
    items.push(...(result.Items || []));
    lastKey = result.LastEvaluatedKey;
  } while (lastKey);
  return items;
}

// ─── Core merge decision ──────────────────────────────────────────────────────
/**
 * Decides whether a new incident should be merged into an existing one.
 *
 * Rules (ALL must pass):
 *  1. Same category.
 *  2. Location proximity: coordinates within 300 m OR locationText similarity >= 0.6.
 *     - Empty/null locationText NEVER counts as a location match.
 *     - Coordinates alone are necessary but not sufficient (see rule 3).
 *  3. Location texts must NOT contradict each other (both non-empty with zero
 *     shared meaningful tokens => distinct places => no merge).
 *  4. Translated messages share >= 25% of their meaningful words (Jaccard).
 *
 * Returns true if all conditions are met.
 */
function shouldMerge(existing, incoming) {
  // ── 1. Same category ──
  if (existing.category !== incoming.category) return false;

  // ── 2. Location proximity ──
  let coordsClose = false;
  if (
    existing.latitude != null &&
    existing.longitude != null &&
    incoming.latitude != null &&
    incoming.longitude != null
  ) {
    const dist = haversineMetres(
      { lat: existing.latitude, lng: existing.longitude },
      { lat: incoming.latitude, lng: incoming.longitude }
    );
    coordsClose = dist <= 300;
  }

  const locationSim = locationTextSimilarity(
    existing.locationText,
    incoming.locationText
  );
  const textLocationMatch = locationSim >= 0.6;

  // At least one location signal must fire
  if (!coordsClose && !textLocationMatch) return false;

  // 2b. If only coords fired (no locationText match), require that at least one
  //     incident has a non-empty locationText — "empty location is never a match"
  //     means we need textual confirmation when GPS is the sole signal.
  if (coordsClose && !textLocationMatch) {
    const existingHasText = !!(existing.locationText && existing.locationText.trim());
    const incomingHasText = !!(incoming.locationText && incoming.locationText.trim());
    if (!existingHasText && !incomingHasText) return false;
  }

  // ── 3. Location texts must not contradict ──
  if (locationTextsContradict(existing.locationText, incoming.locationText)) {
    return false;
  }

  // ── 4. Message content overlap >= 25% ──
  const overlap = messageOverlap(
    existing.translatedMessage || existing.rawMessage,
    incoming.translatedMessage || incoming.rawMessage
  );
  if (overlap < 0.25) return false;

  return true;
}

// ─── Public API ───────────────────────────────────────────────────────────────
/**
 * Attempt to merge the given incident with existing open incidents.
 * If a match is found the existing row is UPDATED in DynamoDB here
 * (the caller skips the PutCommand when merged === true).
 */
async function mergeIncident(incident, docClient, tableName) {
  const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
  const openIncidents = await scanOpenRecent(docClient, tableName, twoHoursAgo);

  for (const existing of openIncidents) {
    if (!shouldMerge(existing, incident)) continue;

    // ── Merge ──
    const updatedReports = (existing.reports || []).concat({
      timestamp: incident.timestamp,
      rawMessage: incident.rawMessage,
    });
    const cappedReports = updatedReports.slice(-20);

    const newUrgency = maxUrgency(existing.urgency, incident.urgency);
    const newPeople = Math.max(
      existing.peopleAffected || 1,
      incident.peopleAffected || 1
    );

    const result = await docClient.send(
      new UpdateCommand({
        TableName: tableName,
        Key: { incidentId: existing.incidentId },
        UpdateExpression:
          "SET reportCount = if_not_exists(reportCount, :zero) + :inc, " +
          "peopleAffected = :people, " +
          "urgency = :urg, " +
          "reports = :reports, " +
          "updatedAt = :now",
        ExpressionAttributeValues: {
          ":inc": 1,
          ":zero": 0,
          ":people": newPeople,
          ":urg": newUrgency,
          ":reports": cappedReports,
          ":now": new Date().toISOString(),
        },
        ReturnValues: "ALL_NEW",
      })
    );
    return { incident: result.Attributes, merged: true };
  }

  return { incident, merged: false };
}

module.exports = {
  mergeIncident,
  shouldMerge,
  locationTextSimilarity,
  locationTextsContradict,
  messageOverlap,
  haversineMetres,
};

