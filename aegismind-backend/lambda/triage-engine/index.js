// Phase A Lambda handler (CommonJS)
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  PutCommand,
  ScanCommand,
  UpdateCommand,
  GetCommand,
} = require("@aws-sdk/lib-dynamodb");
const crypto = require("crypto");

const { getRuleFloor, getRuleAnalysis } = require("./rules");
const { callGemini } = require("./gemini");
const { mergeIncident } = require("./cluster");

const dbClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(dbClient);

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type, X-API-Key",
  "Access-Control-Allow-Methods": "OPTIONS,POST,GET,PATCH",
};

// ───────────────────── Enum allow-lists ─────────────────────
const VALID_URGENCIES = ["CRITICAL", "HIGH", "MEDIUM", "LOW"];
const VALID_CATEGORIES = [
  "MEDICAL",
  "FIRE",
  "FLOOD",
  "COLLAPSE",
  "ACCIDENT",
  "RESCUE",
  "OTHER",
];
const VALID_RESOURCES = [
  "AMBULANCE",
  "FIRE_ENGINE",
  "RESCUE_TEAM",
  "BOAT",
  "POLICE",
  "MEDICAL_TEAM",
];
const URGENCY_ORDER = { LOW: 0, MEDIUM: 1, HIGH: 2, CRITICAL: 3 };

function maxUrgency(a, b) {
  return (URGENCY_ORDER[a] || 0) >= (URGENCY_ORDER[b] || 0) ? a : b;
}

// Minimum required resources per category for CRITICAL or HIGH incidents.
const CATEGORY_MIN_RESOURCES = {
  RESCUE: ["RESCUE_TEAM", "AMBULANCE"],
  FLOOD:  ["RESCUE_TEAM", "BOAT"],
  FIRE:   ["FIRE_ENGINE", "AMBULANCE"],
  COLLAPSE: ["RESCUE_TEAM", "AMBULANCE"],
  MEDICAL: ["AMBULANCE"],
  ACCIDENT: ["AMBULANCE"],
};

/**
 * If the incident is CRITICAL or HIGH and requiredResources is empty (or only OTHER),
 * fill it with the category minimum. Also add BOAT when category is RESCUE.
 */
function ensureResources(category, urgency, resources) {
  const isHighOrCritical = urgency === "CRITICAL" || urgency === "HIGH";
  if (!isHighOrCritical) return resources;
  const current = Array.isArray(resources) ? resources : [];
  const minimum = CATEGORY_MIN_RESOURCES[category] || [];
  if (minimum.length === 0) return current;
  const merged = [...new Set([...current, ...minimum])];
  // RESCUE always gets a BOAT
  if (category === "RESCUE" && !merged.includes("BOAT")) merged.push("BOAT");
  return merged;
}

// ───────────────── Rules-only fallback (item 4) ─────────────
// Maps keywords (English + Hindi/Hinglish from rules.js) to category + resources.
const KEYWORD_MAP = [
  // FIRE
  { words: ["fire", "aag", "jal"], category: "FIRE", resources: ["FIRE_ENGINE"] },
  // MEDICAL
  {
    words: [
      "bleeding", "injured", "unconscious", "not breathing",
      "saans nahi", "bachao", "madad",
    ],
    category: "MEDICAL",
    resources: ["AMBULANCE"],
  },
  // FLOOD / DROWNING
  {
    words: ["flood", "drowning", "doob"],
    category: "FLOOD",
    resources: ["BOAT"],
  },
  // COLLAPSE / TRAPPED
  {
    words: ["trapped", "collapsed", "collapse", "fas gaye"],
    category: "COLLAPSE",
    resources: ["RESCUE_TEAM"],
  },
  // ACCIDENT
  {
    words: ["accident", "road"],
    category: "ACCIDENT",
    resources: ["AMBULANCE", "POLICE"],
  },
];

/**
 * Build a rules-only triage from the raw message.
 * Always produces a complete, saveable triage object.
 */
function buildRulesFallback(rawMessage, ruleFloor, locationText) {
  const lower = rawMessage.toLowerCase();
  let category = "OTHER";
  let resources = [];
  for (const entry of KEYWORD_MAP) {
    if (entry.words.some((kw) => lower.includes(kw))) {
      category = entry.category;
      resources = entry.resources;
      break;
    }
  }
  return {
    language: "unknown",
    translatedMessage: rawMessage,
    category,
    urgency: ruleFloor,
    peopleAffected: 1,
    locationText: locationText || "",
    confidence: 0,
    reason: "Rules-only fallback (Gemini unavailable or returned invalid data)",
    keyPhrases: [],
    requiredResources: resources,
    safetyAdvice: "Stay calm. Seek local help if possible.",
    summary: rawMessage.slice(0, 120),
  };
}

// ────────────── Model-output validation (item 3) ────────────
function validateTriageData(raw) {
  const out = { ...raw };

  // urgency — normalise & clamp
  out.urgency = typeof out.urgency === "string" ? out.urgency.toUpperCase() : "LOW";
  if (!VALID_URGENCIES.includes(out.urgency)) out.urgency = "LOW";

  // category — normalise & clamp
  out.category = typeof out.category === "string" ? out.category.toUpperCase() : "OTHER";
  if (!VALID_CATEGORIES.includes(out.category)) out.category = "OTHER";

  // requiredResources — keep only allowed
  out.requiredResources = Array.isArray(out.requiredResources)
    ? out.requiredResources.filter((r) => VALID_RESOURCES.includes(r))
    : [];

  // peopleAffected — integer >= 1
  out.peopleAffected = Math.max(1, Math.floor(Number(out.peopleAffected) || 1));

  // confidence — number 0-1, default 0.5
  let conf = Number(out.confidence);
  if (!Number.isFinite(conf)) {
    conf = 0.5;
  } else {
    conf = Math.min(1, Math.max(0, conf));
  }
  out.confidence = conf;

  // Ensure strings exist
  out.language = out.language || "unknown";
  out.translatedMessage = out.translatedMessage || "";
  out.reason = out.reason || "";
  out.safetyAdvice = out.safetyAdvice || "";
  out.summary = out.summary || "";
  out.keyPhrases = Array.isArray(out.keyPhrases) ? out.keyPhrases : [];

  return out;
}

// ────────────────── Safe JSON parse (item 5) ────────────────
function safeParse(raw) {
  try {
    return { ok: true, value: JSON.parse(raw || "{}") };
  } catch (_) {
    return { ok: false };
  }
}

// ─────────────── Validate POST payload ──────────────────────
function validatePostBody(body) {
  if (!body || typeof body.message !== "string") {
    return { valid: false, error: "'message' field is required and must be a string" };
  }
  const trimmed = body.message.trim();
  if (trimmed.length === 0 || trimmed.length > 1000) {
    return { valid: false, error: "'message' must be 1-1000 characters after trimming" };
  }
  return { valid: true, message: trimmed };
}

// ═════════════════════════ HANDLER ═══════════════════════════
exports.handler = async (event) => {
  // ── OPTIONS (CORS pre-flight) ──
  if (event.httpMethod === "OPTIONS") {
    return { statusCode: 200, headers: CORS, body: "" };
  }

  // ── GET /sos — list incidents (newest first) ──
  if (event.httpMethod === "GET" && !event.pathParameters?.incidentId) {
    try {
      // Scan is capped at 1 MB per response; include every page so the
      // dispatcher does not silently lose older incidents.
      const items = [];
      let exclusiveStartKey;
      do {
        const result = await docClient.send(
          new ScanCommand({
            TableName: process.env.TABLE_NAME,
            ...(exclusiveStartKey ? { ExclusiveStartKey: exclusiveStartKey } : {}),
          })
        );
        items.push(...(result.Items || []));
        exclusiveStartKey = result.LastEvaluatedKey;
      } while (exclusiveStartKey);

      items.sort(
        (a, b) => new Date(b.timestamp) - new Date(a.timestamp)
      );
      return { statusCode: 200, headers: CORS, body: JSON.stringify(items) };
    } catch (err) {
      return {
        statusCode: 500,
        headers: CORS,
        body: JSON.stringify({ error: err.message }),
      };
    }
  }

  // ── GET /sos/{incidentId} — fetch specific incident ──
  if (event.httpMethod === "GET" && event.pathParameters?.incidentId) {
    // Incident IDs are stored lowercase. Normalise external path input before
    // choosing a lookup strategy or sending it to DynamoDB.
    const incidentId = event.pathParameters.incidentId.trim().toLowerCase();
    let incident = null;

    try {
      if (incidentId.length === 8) {
        // Short IDs are prefixes, so scan until a match is found or every page
        // has been examined. A single Scan response is limited to 1 MB.
        let exclusiveStartKey;
        do {
          const result = await docClient.send(
            new ScanCommand({
              TableName: process.env.TABLE_NAME,
              FilterExpression: "begins_with(incidentId, :ref)",
              ExpressionAttributeValues: { ":ref": incidentId },
              ...(exclusiveStartKey ? { ExclusiveStartKey: exclusiveStartKey } : {}),
            })
          );
          incident = result.Items?.[0] || null;
          exclusiveStartKey = result.LastEvaluatedKey;
        } while (!incident && exclusiveStartKey);
      } else {
        // Full UUID: use GetCommand
        const result = await docClient.send(
          new GetCommand({
            TableName: process.env.TABLE_NAME,
            Key: { incidentId },
          })
        );
        incident = result.Item;
      }

      if (!incident) {
        return {
          statusCode: 404,
          headers: CORS,
          body: JSON.stringify({ error: "Incident not found" }),
        };
      }

      // Return ONLY specific fields, never leak private details
      const referenceId = incident.incidentId.substring(0, 8).toUpperCase();
      const publicData = {
        referenceId,
        status: incident.status,
        urgency: incident.urgency,
        category: incident.category,
        assignedResources: incident.assignedResources || [],
        updatedAt: incident.updatedAt,
        reportCount: incident.reportCount || 1,
      };
      if (incident.etaMinutes !== undefined && incident.etaMinutes !== null) {
        publicData.etaMinutes = incident.etaMinutes;
      }

      return {
        statusCode: 200,
        headers: CORS,
        body: JSON.stringify(publicData),
      };
    } catch (err) {
      return {
        statusCode: 500,
        headers: CORS,
        body: JSON.stringify({ error: err.message }),
      };
    }
  }

  // ── PATCH /sos/{incidentId} — update status/resources/review/eta ──
  if (event.httpMethod === "PATCH") {
    const incidentId = event.pathParameters?.incidentId;
    if (!incidentId) {
      return {
        statusCode: 400,
        headers: CORS,
        body: JSON.stringify({ error: "Missing incidentId" }),
      };
    }

    const parsed = safeParse(event.body);
    if (!parsed.ok) {
      return {
        statusCode: 400,
        headers: CORS,
        body: JSON.stringify({ error: "Request body is not valid JSON" }),
      };
    }
    const body = parsed.value;

    const updates = {};
    if (body.status) {
      if (!["OPEN", "DISPATCHED", "RESOLVED"].includes(body.status)) {
        return {
          statusCode: 400,
          headers: CORS,
          body: JSON.stringify({ error: "Invalid status value" }),
        };
      }
      updates.status = body.status;
    }
    if (Array.isArray(body.assignedResources))
      updates.assignedResources = body.assignedResources;
    if (typeof body.needsReview === "boolean")
      updates.needsReview = body.needsReview;
    if (typeof body.etaMinutes === "number" && body.etaMinutes >= 0 && body.etaMinutes <= 600)
      updates.etaMinutes = body.etaMinutes;

    if (Object.keys(updates).length === 0) {
      return {
        statusCode: 400,
        headers: CORS,
        body: JSON.stringify({ error: "No updatable fields provided" }),
      };
    }

    // Build update expression dynamically
    const expr = [];
    const names = {};
    const values = {};
    let i = 0;
    for (const [k, v] of Object.entries(updates)) {
      const nk = `#k${i}`;
      const vk = `:v${i}`;
      names[nk] = k;
      values[vk] = v;
      expr.push(`${nk} = ${vk}`);
      i++;
    }
    // always bump updatedAt
    names[`#k${i}`] = "updatedAt";
    values[`:v${i}`] = new Date().toISOString();
    expr.push(`#k${i} = :v${i}`);

    try {
      const result = await docClient.send(
        new UpdateCommand({
          TableName: process.env.TABLE_NAME,
          Key: { incidentId },
          UpdateExpression: "SET " + expr.join(", "),
          ConditionExpression: "attribute_exists(incidentId)",
          ExpressionAttributeNames: names,
          ExpressionAttributeValues: values,
          ReturnValues: "ALL_NEW",
        })
      );
      return {
        statusCode: 200,
        headers: CORS,
        body: JSON.stringify(result.Attributes),
      };
    } catch (err) {
      if (err.name === "ConditionalCheckFailedException") {
        return {
          statusCode: 404,
          headers: CORS,
          body: JSON.stringify({ error: "Incident not found" }),
        };
      }
      return {
        statusCode: 500,
        headers: CORS,
        body: JSON.stringify({ error: err.message }),
      };
    }
  }

  // ── POST /sos — create new incident ──
  if (event.httpMethod === "POST") {
    const parsed = safeParse(event.body);
    if (!parsed.ok) {
      return {
        statusCode: 400,
        headers: CORS,
        body: JSON.stringify({ error: "Request body is not valid JSON" }),
      };
    }
    const body = parsed.value;

    const validation = validatePostBody(body);
    if (!validation.valid) {
      return {
        statusCode: 400,
        headers: CORS,
        body: JSON.stringify({ error: validation.error }),
      };
    }
    const rawMessage = validation.message;
    const ruleFloor = getRuleFloor(rawMessage);

    // ── Call Gemini (failures ALWAYS fall back to rules) ──
    let triageData;
    let triageSource = "rules-fallback";
    let needsReview = true;

    const geminiResult = await callGemini(rawMessage);

    if (!geminiResult.error && geminiResult.data) {
      // Gemini returned something — validate it
      triageData = validateTriageData(geminiResult.data);
      triageSource = "gemini";
      needsReview = triageData.confidence < 0.6;

      // ── Category accuracy override ──
      // If the model returned OTHER but rules found a specific category, use it.
      const ruleAnalysis = getRuleAnalysis(rawMessage);
      if (triageData.category === "OTHER" && ruleAnalysis.category) {
        triageData.category = ruleAnalysis.category;
        triageData.reason = `[Category overridden from OTHER to ${ruleAnalysis.category} by rule engine] ` + triageData.reason;
        needsReview = true;
      }

      // ── Resource floor for CRITICAL / HIGH ──
      // After final urgency is computed below, resources may still be empty; patch here
      // using the final urgency will be done after maxUrgency, so pre-compute it now.
      const provisionalUrgency = maxUrgency(ruleFloor, triageData.urgency);
      triageData.requiredResources = ensureResources(
        triageData.category,
        provisionalUrgency,
        triageData.requiredResources
      );
    } else {
      // Gemini call failed entirely — rules-only fallback
      triageData = buildRulesFallback(rawMessage, ruleFloor, body.locationText);
      triageData.triageError = (geminiResult.error?.message || "Unknown error").substring(0, 200);
    }

    // Final urgency = max(rule floor, triage urgency)
    const finalUrgency = maxUrgency(ruleFloor, triageData.urgency);

    const incidentItem = {
      incidentId: crypto.randomUUID(),
      timestamp: new Date().toISOString(),
      rawMessage,
      latitude: body.latitude ?? null,
      longitude: body.longitude ?? null,
      locationText: body.locationText ?? triageData.locationText ?? null,
      language: triageData.language,
      translatedMessage: triageData.translatedMessage,
      category: triageData.category,
      urgency: finalUrgency,
      peopleAffected: triageData.peopleAffected,
      confidence: triageData.confidence,
      reason: triageData.reason,
      keyPhrases: triageData.keyPhrases,
      requiredResources: triageData.requiredResources,
      safetyAdvice: triageData.safetyAdvice,
      summary: triageData.summary,
      status: "OPEN",
      needsReview,
      triageSource,
      triageError: triageData.triageError || null,
      reportCount: 1,
      reports: [{ timestamp: new Date().toISOString(), rawMessage }],
      assignedResources: [],
      updatedAt: new Date().toISOString(),
    };

    try {
      // Merge / clustering logic (cluster.js writes to DDB on merge)
      const { incident: finalIncident, merged } = await mergeIncident(
        incidentItem,
        docClient,
        process.env.TABLE_NAME
      );

      if (!merged) {
        await docClient.send(
          new PutCommand({ TableName: process.env.TABLE_NAME, Item: finalIncident })
        );
      }

      return {
        statusCode: 201,
        headers: CORS,
        body: JSON.stringify({ incident: finalIncident, merged }),
      };
    } catch (err) {
      return {
        statusCode: 500,
        headers: CORS,
        body: JSON.stringify({ error: err.message }),
      };
    }
  }

  return {
    statusCode: 405,
    headers: CORS,
    body: JSON.stringify({ error: "Method not allowed" }),
  };
};
