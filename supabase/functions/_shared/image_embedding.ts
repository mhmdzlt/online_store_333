/// <reference lib="deno.ns" />
/// <reference lib="dom" />

const DEFAULT_EMBEDDING_URL =
  "https://vinithius-get-embedding-image-512d.hf.space/embed";

export type EmbeddingBackendConfig = {
  embeddingUrl?: string;
  huggingFaceApiKey?: string;
  targetDim?: number;
};

export async function getEmbeddingFromImageBytes(
  imageBytes: Uint8Array,
  config: EmbeddingBackendConfig = {},
): Promise<number[]> {
  const mimeType = sniffImageMimeType(imageBytes);
  const dataUrl = `data:${mimeType};base64,${encodeBase64(imageBytes)}`;

  const headers = new Headers({
    "Content-Type": "application/json",
  });

  if (config.huggingFaceApiKey) {
    headers.set("Authorization", `Bearer ${config.huggingFaceApiKey}`);
  }

  const embeddingUrl = config.embeddingUrl ?? DEFAULT_EMBEDDING_URL;
  const targetDim = config.targetDim ?? 512;

  const resp = await fetch(embeddingUrl, {
    method: "POST",
    headers,
    body: JSON.stringify({
      image: dataUrl,
      target_dim: targetDim,
      use_float16: false,
    }),
  });

  const rawText = await resp.text();
  const parsed = safeJsonParse(rawText);

  if (!resp.ok) {
    const message =
      (parsed && typeof parsed === "object" && "detail" in parsed &&
          typeof (parsed as any).detail === "string")
        ? (parsed as any).detail
        : rawText.slice(0, 500);

    throw new Error(`Embedding backend error (${resp.status}): ${message}`);
  }

  if (!parsed || typeof parsed !== "object") return [];

  const embedding = (parsed as any).embedding;
  if (
    !Array.isArray(embedding) ||
    !embedding.every((n: unknown) => typeof n === "number")
  ) {
    return [];
  }

  return embedding as number[];
}

export function sniffImageMimeType(bytes: Uint8Array): string {
  if (bytes.length >= 12) {
    // PNG
    if (
      bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e &&
      bytes[3] === 0x47
    ) {
      return "image/png";
    }

    // JPEG
    if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
      return "image/jpeg";
    }

    // GIF
    if (bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46) {
      return "image/gif";
    }

    // WEBP: RIFF....WEBP
    if (
      bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 &&
      bytes[3] === 0x46 &&
      bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 &&
      bytes[11] === 0x50
    ) {
      return "image/webp";
    }
  }

  return "image/jpeg";
}

export function safeJsonParse(input: string): unknown | null {
  try {
    return JSON.parse(input);
  } catch {
    return null;
  }
}

export function encodeBase64(bytes: Uint8Array): string {
  // Avoid call-stack limits by chunking.
  const chunkSize = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}
