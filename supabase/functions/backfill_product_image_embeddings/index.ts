/// <reference lib="deno.ns" />
/// <reference lib="dom" />

// @ts-expect-error Deno resolves remote modules at runtime.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { getEmbeddingFromImageBytes } from "../_shared/image_embedding.ts";

type BackfillRequestBody = {
  limit?: number;
  dry_run?: boolean;
};

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
    const secret = Deno.env.get("BACKFILL_SECRET");
    const provided = req.headers.get("x-backfill-secret");

    if (!secret || !provided || provided !== secret) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: "Missing Supabase env vars" }, 500);
    }

    const url = new URL(req.url);
    const limitFromQuery = parseOptionalInt(url.searchParams.get("limit"));
    const dryRunFromQuery = parseOptionalBool(url.searchParams.get("dry_run"));

    const body = await readJsonBody(req);
    const limit = clampInt(limitFromQuery ?? body?.limit ?? 50, 1, 500);
    const dryRun = Boolean(dryRunFromQuery ?? body?.dry_run ?? false);

    const embeddingUrl = Deno.env.get("IMAGE_EMBEDDING_URL") ?? undefined;
    const hfKey = Deno.env.get("HUGGINGFACE_API_KEY") ?? undefined;
    const expectedDim = Number(Deno.env.get("IMAGE_EMBEDDING_DIM") ?? "512");

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: products, error: selectError } = await supabase
      .from("products")
      .select("id,image_url")
      .is("image_embedding", null)
      .limit(limit);

    if (selectError) {
      return jsonResponse({ error: selectError.message }, 500);
    }

    const items = products ?? [];

    let processed = 0;
    let updated = 0;
    let skipped = 0;
    const errors: Array<{ id?: string; error: string }> = [];

    for (const item of items) {
      processed++;

      const id = (item as any).id as string | undefined;
      let imageUrl = (item as any).image_url as string | null | undefined;

      if (!id) {
        skipped++;
        continue;
      }

      if (!imageUrl) {
        const { data: imageRows, error: imageError } = await supabase
          .from("product_images")
          .select("image_url")
          .eq("product_id", id)
          .order("sort_order", { ascending: true })
          .limit(1);

        if (imageError) {
          errors.push({ id, error: imageError.message });
          continue;
        }

        if (imageRows && imageRows.length > 0) {
          imageUrl = (imageRows[0] as any).image_url as string | null | undefined;
        }
      }

      if (!imageUrl || isPlaceholderUrl(imageUrl)) {
        skipped++;
        continue;
      }

      try {
        const imageBytes = await downloadImageBytes({
          imageUrl,
          supabaseUrl,
          serviceRoleKey,
        });
        const embedding = await getEmbeddingFromImageBytes(imageBytes, {
          embeddingUrl,
          huggingFaceApiKey: hfKey,
          targetDim: 512,
        });

        if (!embedding.length) {
          skipped++;
          continue;
        }

        if (
          !Number.isNaN(expectedDim) && expectedDim > 0 &&
          embedding.length !== expectedDim
        ) {
          errors.push({
            id,
            error:
              `Unexpected embedding dimension: expected=${expectedDim}, actual=${embedding.length}`,
          });
          continue;
        }

        const vector = "[" + embedding.map((n) => n.toFixed(6)).join(",") + "]";

        if (dryRun) {
          updated++;
          continue;
        }

        const { error: updateError } = await supabase
          .from("products")
          .update({ image_embedding: vector })
          .eq("id", id);

        if (updateError) {
          errors.push({ id, error: updateError.message });
          continue;
        }

        updated++;
      } catch (e) {
        errors.push({ id, error: String(e) });
      }
    }

    return jsonResponse({
      processed,
      updated,
      skipped,
      dry_run: dryRun,
      errors: errors.slice(0, 20),
    });
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

async function readJsonBody(req: Request): Promise<BackfillRequestBody | null> {
  try {
    const raw = await req.text();
    if (!raw) return null;
    return JSON.parse(raw) as BackfillRequestBody;
  } catch {
    return null;
  }
}

function clampInt(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.max(min, Math.min(max, Math.trunc(value)));
}

function parseOptionalInt(value: string | null): number | null {
  if (!value) return null;
  const parsed = Number(value);
  if (Number.isNaN(parsed)) return null;
  return Math.trunc(parsed);
}

function parseOptionalBool(value: string | null): boolean | null {
  if (!value) return null;
  const lowered = value.toLowerCase();
  if (lowered === "true" || lowered === "1" || lowered === "yes") return true;
  if (lowered === "false" || lowered === "0" || lowered === "no") return false;
  return null;
}

function isPlaceholderUrl(url: string): boolean {
  const lowered = url.toLowerCase();
  return lowered.includes("placeholder.com") || lowered.includes("via.placeholder.com");
}

function looksLikeUrl(value: string): boolean {
  return value.startsWith("http://") || value.startsWith("https://");
}

type DownloadImageBytesArgs = {
  imageUrl: string;
  supabaseUrl: string;
  serviceRoleKey: string;
};

async function downloadImageBytes(args: DownloadImageBytesArgs): Promise<Uint8Array> {
  const { imageUrl, supabaseUrl, serviceRoleKey } = args;

  // If the DB stored a bucket/path style reference (ex: "product-images/foo.jpg"),
  // try to download from Supabase Storage using service role.
  if (!looksLikeUrl(imageUrl)) {
    const normalized = imageUrl.replace(/^\/+/, "");
    const firstSlash = normalized.indexOf("/");
    if (firstSlash > 0) {
      const bucket = normalized.slice(0, firstSlash);
      const path = normalized.slice(firstSlash + 1);
      const supabase = createClient(supabaseUrl, serviceRoleKey);
      const { data, error } = await supabase.storage.from(bucket).download(path);
      if (error) {
        throw new Error(`Storage download failed: ${error.message}`);
      }
      if (!data) {
        throw new Error("Storage download returned empty data");
      }
      const buffer = await data.arrayBuffer();
      return new Uint8Array(buffer);
    }
  }

  const headers = new Headers();
  // Only attach sensitive headers for same-origin Supabase URLs.
  try {
    const target = new URL(imageUrl);
    const origin = new URL(supabaseUrl).origin;
    if (target.origin === origin && target.pathname.startsWith("/storage/v1/object")) {
      headers.set("apikey", serviceRoleKey);
      headers.set("Authorization", `Bearer ${serviceRoleKey}`);
    }
  } catch {
    // ignore URL parsing errors; fall back to plain fetch
  }

  const resp = await fetch(imageUrl, { headers });
  if (!resp.ok) {
    throw new Error(`Failed to download image (${resp.status})`);
  }
  const buffer = await resp.arrayBuffer();
  return new Uint8Array(buffer);
}
