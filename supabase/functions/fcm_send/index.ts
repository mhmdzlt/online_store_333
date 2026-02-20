import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id?: string;
};

const asText = (value: string | undefined): string => (value ?? "").trim();

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function decodeBase64ToString(value: string): string {
  const bytes = Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

function pemToPkcs8Der(pem: string): ArrayBuffer {
  const cleaned = pem
    .replaceAll("-----BEGIN PRIVATE KEY-----", "")
    .replaceAll("-----END PRIVATE KEY-----", "")
    .replaceAll("\n", "")
    .replaceAll("\r", "")
    .trim();
  const bytes = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
  return bytes.buffer;
}

function base64UrlEncode(bytes: Uint8Array): string {
  const b64 = btoa(String.fromCharCode(...bytes));
  return b64.replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function base64UrlEncodeString(text: string): string {
  return base64UrlEncode(new TextEncoder().encode(text));
}

async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const unsigned =
    `${base64UrlEncodeString(JSON.stringify(header))}.` +
    `${base64UrlEncodeString(JSON.stringify(payload))}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8Der(serviceAccount.private_key),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    new TextEncoder().encode(unsigned),
  );

  const jwt = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`TOKEN_EXCHANGE_FAILED:${res.status}:${text}`);
  }

  const json = (await res.json()) as { access_token?: string };
  const token = asText(json.access_token);
  if (!token) throw new Error("TOKEN_MISSING");
  return token;
}

async function sendToToken(params: {
  accessToken: string;
  projectId: string;
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<void> {
  const url = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(params.projectId)}/messages:send`;

  const payload = {
    message: {
      token: params.token,
      notification: {
        title: params.title,
        body: params.body,
      },
      data: params.data,
      android: {
        notification: {
          channel_id: "high_importance_channel",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${params.accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`FCM_SEND_FAILED:${res.status}:${text}`);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "METHOD_NOT_ALLOWED" });
  }

  const expectedSecret = asText(Deno.env.get("PUSH_SEND_SECRET"));
  const providedSecret = asText(req.headers.get("x-push-secret") ?? undefined);
  if (!expectedSecret || providedSecret !== expectedSecret) {
    return jsonResponse(401, { error: "UNAUTHORIZED" });
  }

  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch (_) {
    return jsonResponse(400, { error: "INVALID_JSON" });
  }

  const phone = asText(typeof body.phone === "string" ? body.phone : undefined);
  const title = asText(typeof body.title === "string" ? body.title : undefined);
  const messageBody = asText(
    typeof body.body === "string" ? body.body : undefined,
  );

  const token = asText(typeof body.token === "string" ? body.token : undefined);
  const tokensRaw = Array.isArray(body.tokens) ? body.tokens : [];
  const tokens = tokensRaw
    .filter((t) => typeof t === "string")
    .map((t) => asText(t as string))
    .filter(Boolean);

  const route = asText(typeof body.route === "string" ? body.route : undefined);

  const rawData = body.data;
  const data: Record<string, string> = {};
  if (rawData && typeof rawData === "object" && !Array.isArray(rawData)) {
    for (const [k, v] of Object.entries(rawData as Record<string, unknown>)) {
      if (typeof v === "string") data[k] = v;
      else if (typeof v === "number" || typeof v === "boolean") {
        data[k] = String(v);
      }
    }
  }

  if (route && !data.route) data.route = route;

  if (!title || !messageBody) {
    return jsonResponse(400, { error: "TITLE_AND_BODY_REQUIRED" });
  }

  const supabaseUrl = asText(Deno.env.get("SUPABASE_URL"));
  const supabaseServiceRoleKey = asText(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));
  if (!supabaseUrl || !supabaseServiceRoleKey) {
    return jsonResponse(500, { error: "SUPABASE_ENV_MISSING" });
  }

  const serviceAccountB64 = asText(
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON_B64"),
  );
  const serviceAccountRaw = asText(Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON"));
  const serviceAccountJson = serviceAccountRaw ||
    (serviceAccountB64 ? decodeBase64ToString(serviceAccountB64) : "");

  let serviceAccount: ServiceAccount;
  try {
    serviceAccount = JSON.parse(serviceAccountJson) as ServiceAccount;
  } catch (_) {
    return jsonResponse(500, { error: "SERVICE_ACCOUNT_SECRET_INVALID" });
  }

  const projectId = firstNonEmpty(
    asText(Deno.env.get("FIREBASE_PROJECT_ID")),
    asText(serviceAccount.project_id),
  );

  if (!serviceAccount.client_email || !serviceAccount.private_key || !projectId) {
    return jsonResponse(500, { error: "SERVICE_ACCOUNT_SECRET_MISSING_FIELDS" });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

  const targetTokens: string[] = [];
  if (token) targetTokens.push(token);
  targetTokens.push(...tokens);

  if (targetTokens.length === 0) {
    if (!phone) {
      return jsonResponse(400, { error: "PHONE_OR_TOKEN_REQUIRED" });
    }

    const { data: rows, error } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("phone", phone)
      .eq("is_active", true);

    if (error) {
      return jsonResponse(500, { error: "DB_QUERY_FAILED" });
    }

    for (const row of rows ?? []) {
      const t = asText((row as Record<string, unknown>).token as string | undefined);
      if (t) targetTokens.push(t);
    }
  }

  const uniqueTokens = Array.from(new Set(targetTokens)).filter(Boolean);
  if (uniqueTokens.length === 0) {
    return jsonResponse(200, { ok: true, sent: 0, skipped: "NO_TOKENS" });
  }

  let accessToken: string;
  try {
    accessToken = await getAccessToken(serviceAccount);
  } catch (e) {
    return jsonResponse(500, { error: "ACCESS_TOKEN_FAILED", message: String(e) });
  }

  let sent = 0;
  const errors: string[] = [];

  for (const t of uniqueTokens) {
    try {
      await sendToToken({
        accessToken,
        projectId,
        token: t,
        title,
        body: messageBody,
        data,
      });
      sent += 1;
    } catch (e) {
      errors.push(String(e));
    }
  }

  return jsonResponse(200, {
    ok: true,
    sent,
    failed: errors.length,
    errors: errors.slice(0, 5),
  });
});

function firstNonEmpty(...values: Array<string | undefined>): string {
  for (const v of values) {
    const t = asText(v);
    if (t) return t;
  }
  return "";
}
