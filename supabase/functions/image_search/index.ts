/// <reference lib="deno.ns" />
/// <reference lib="dom" />
// @ts-expect-error Deno resolves remote modules at runtime.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { getEmbeddingFromImageBytes } from "../_shared/image_embedding.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: corsHeaders,
    });
  }

  try {
    const imageBytes = await readImageBytes(req);
    if (!imageBytes) {
      return jsonResponse({ error: "Missing image" }, 400);
    }

    const embeddingUrl = Deno.env.get("IMAGE_EMBEDDING_URL") ?? undefined;
    const hfKey = Deno.env.get("HUGGINGFACE_API_KEY") ?? undefined;
    const embedding = await getEmbeddingFromImageBytes(imageBytes, {
      embeddingUrl,
      huggingFaceApiKey: hfKey,
      targetDim: 512,
    });
    if (!embedding.length) {
      return jsonResponse({ error: "Embedding is empty" }, 500);
    }

    const expectedDim = Number(Deno.env.get("IMAGE_EMBEDDING_DIM") ?? "512");
    if (!Number.isNaN(expectedDim) && expectedDim > 0 && embedding.length !== expectedDim) {
      return jsonResponse(
        {
          error: "Unexpected embedding dimension",
          expected: expectedDim,
          actual: embedding.length,
        },
        500,
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: "Missing Supabase env vars" }, 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const matchCount = await readMatchCount(req);

    const vector =
      "[" + embedding.map((n) => n.toFixed(6)).join(",") + "]";

    const { data, error } = await supabase.rpc(
      "search_products_by_image_embedding",
      {
        p_embedding: vector,
        p_match_count: matchCount,
      }
    );

    if (error) {
      return jsonResponse({ error: error.message }, 500);
    }

    // Give a more actionable hint in the common misconfiguration case:
    // if no product rows have embeddings, RPC will always return [].
    if (!Array.isArray(data) || data.length === 0) {
      const { count } = await supabase
        .from("products")
        .select("id", { count: "exact", head: true })
        .not("image_embedding", "is", null);

      if ((count ?? 0) === 0) {
        return jsonResponse({
          results: [],
          warning:
            "No products have image_embedding populated yet. Run a backfill to generate/store embeddings for product images.",
        });
      }
    }

    return jsonResponse({ results: data ?? [] });
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

async function readImageBytes(req: Request): Promise<Uint8Array | null> {
  const contentType = req.headers.get("content-type") ?? "";

  if (contentType.includes("multipart/form-data")) {
    const form = await req.formData();
    const file = form.get("image");
    if (!(file instanceof File)) return null;
    const buffer = await file.arrayBuffer();
    return new Uint8Array(buffer);
  }

  if (contentType.includes("application/json")) {
    const payload = await req.json();
    const base64 = payload?.image_base64;
    if (typeof base64 !== "string") return null;
    return decodeBase64(base64);
  }

  if (contentType.startsWith("image/")) {
    const buffer = await req.arrayBuffer();
    return new Uint8Array(buffer);
  }

  return null;
}

async function readMatchCount(req: Request): Promise<number> {
  const url = new URL(req.url);
  const param = url.searchParams.get("limit");
  if (param) {
    const parsed = Number(param);
    if (!Number.isNaN(parsed) && parsed > 0 && parsed <= 50) {
      return parsed;
    }
  }
  return 20;
}

function decodeBase64(value: string): Uint8Array {
  const sanitized = value.includes(",")
    ? value.substring(value.indexOf(",") + 1)
    : value;
  const binary = atob(sanitized);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}
