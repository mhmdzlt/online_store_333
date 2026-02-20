import { corsHeaders } from "../_shared/cors.ts";

type AppKind = "seller" | "admin";

const asText = (value: string | undefined): string => (value ?? "").trim();

const firstNonEmpty = (...values: Array<string | undefined>): string => {
  for (const value of values) {
    const text = asText(value);
    if (text) return text;
  }
  return "";
};

function readEnvAliases(keys: string[]): string {
  for (const key of keys) {
    const value = asText(Deno.env.get(key));
    if (value) return value;
  }
  return "";
}

async function pickApp(req: Request): Promise<AppKind> {
  try {
    const url = new URL(req.url);
    const queryApp = (url.searchParams.get("app") ?? "").trim().toLowerCase();
    if (queryApp === "seller" || queryApp === "admin") return queryApp;
  } catch (_) {
    // ignore
  }

  if (req.method !== "GET") {
    try {
      const body = await req.clone().json();
      if (body && typeof body === "object") {
        const rawApp = (body as Record<string, unknown>)["app"];
        const app = (typeof rawApp === "string" ? rawApp : "")
          .trim()
          .toLowerCase();
        if (app === "seller" || app === "admin") return app;
      }
    } catch (_) {
      // ignore invalid body
    }
  }

  return "seller";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const app = await pickApp(req);

    const rawMobileConfig = readEnvAliases([
      "FIREBASE_MOBILE_CONFIG_JSON",
      "FIREBASE_RUNTIME_CONFIG_JSON",
    ]);

    let mobileConfig: Record<string, unknown> = {};
    if (rawMobileConfig) {
      try {
        const parsed = JSON.parse(rawMobileConfig);
        if (parsed && typeof parsed === "object") {
          mobileConfig = parsed as Record<string, unknown>;
        }
      } catch (_) {
        // ignore malformed JSON secret
      }
    }

    const appKey = app === "seller" ? "seller" : "admin";
    const appConfig = (mobileConfig[appKey] && typeof mobileConfig[appKey] === "object")
      ? mobileConfig[appKey] as Record<string, unknown>
      : {};

    const rootAndroid = (mobileConfig["android"] && typeof mobileConfig["android"] === "object")
      ? mobileConfig["android"] as Record<string, unknown>
      : {};
    const rootIos = (mobileConfig["ios"] && typeof mobileConfig["ios"] === "object")
      ? mobileConfig["ios"] as Record<string, unknown>
      : {};
    const appAndroid = (appConfig["android"] && typeof appConfig["android"] === "object")
      ? appConfig["android"] as Record<string, unknown>
      : {};
    const appIos = (appConfig["ios"] && typeof appConfig["ios"] === "object")
      ? appConfig["ios"] as Record<string, unknown>
      : {};

    const apiKey = firstNonEmpty(
      readEnvAliases(["FIREBASE_API_KEY", "FIREBASE_WEB_API_KEY"]),
      asText(mobileConfig["apiKey"] as string | undefined),
      asText(mobileConfig["api_key"] as string | undefined),
    );

    const projectId = firstNonEmpty(
      readEnvAliases(["FIREBASE_PROJECT_ID", "FIREBASE_PROJECT"]),
      asText(mobileConfig["projectId"] as string | undefined),
      asText(mobileConfig["project_id"] as string | undefined),
    );

    const messagingSenderId = firstNonEmpty(
      readEnvAliases([
        "FIREBASE_MESSAGING_SENDER_ID",
        "FIREBASE_SENDER_ID",
        "FIREBASE_GCM_SENDER_ID",
      ]),
      asText(mobileConfig["messagingSenderId"] as string | undefined),
      asText(mobileConfig["messaging_sender_id"] as string | undefined),
    );

    const storageBucket = firstNonEmpty(
      readEnvAliases(["FIREBASE_STORAGE_BUCKET"]),
      asText(mobileConfig["storageBucket"] as string | undefined),
      asText(mobileConfig["storage_bucket"] as string | undefined),
    );

    const androidAppId = firstNonEmpty(
      readEnvAliases(
        app === "seller"
          ? [
            "FIREBASE_ANDROID_APP_ID_SELLER",
            "FIREBASE_ANDROID_APP_ID",
            "FIREBASE_SELLER_ANDROID_APP_ID",
          ]
          : [
            "FIREBASE_ANDROID_APP_ID_ADMIN",
            "FIREBASE_ADMIN_ANDROID_APP_ID",
          ],
      ),
      asText(appAndroid["appId"] as string | undefined),
      asText(appAndroid["app_id"] as string | undefined),
      asText(rootAndroid[`${appKey}AppId`] as string | undefined),
      asText(rootAndroid["appId"] as string | undefined),
    );

    const iosAppId = firstNonEmpty(
      readEnvAliases(
        app === "seller"
          ? [
            "FIREBASE_IOS_APP_ID_SELLER",
            "FIREBASE_IOS_APP_ID",
            "FIREBASE_SELLER_IOS_APP_ID",
          ]
          : [
            "FIREBASE_IOS_APP_ID_ADMIN",
            "FIREBASE_ADMIN_IOS_APP_ID",
          ],
      ),
      asText(appIos["appId"] as string | undefined),
      asText(appIos["app_id"] as string | undefined),
      asText(rootIos[`${appKey}AppId`] as string | undefined),
      asText(rootIos["appId"] as string | undefined),
    );

    const iosBundleId = firstNonEmpty(
      readEnvAliases(
        app === "seller"
          ? [
            "FIREBASE_IOS_BUNDLE_ID_SELLER",
            "FIREBASE_IOS_BUNDLE_ID",
            "FIREBASE_SELLER_IOS_BUNDLE_ID",
          ]
          : [
            "FIREBASE_IOS_BUNDLE_ID_ADMIN",
            "FIREBASE_ADMIN_IOS_BUNDLE_ID",
          ],
      ),
      asText(appIos["iosBundleId"] as string | undefined),
      asText(appIos["ios_bundle_id"] as string | undefined),
      asText(rootIos[`${appKey}BundleId`] as string | undefined),
      asText(rootIos["iosBundleId"] as string | undefined),
    );

    const missingKeys = [
      !apiKey ? "apiKey" : "",
      !projectId ? "projectId" : "",
      !messagingSenderId ? "messagingSenderId" : "",
      !androidAppId ? "android.appId" : "",
      !iosAppId ? "ios.appId" : "",
    ].filter(Boolean);

    const fatalMissingKeys = [
      !apiKey ? "apiKey" : "",
      !projectId ? "projectId" : "",
      !messagingSenderId ? "messagingSenderId" : "",
      !androidAppId && !iosAppId ? "appId" : "",
    ].filter(Boolean);

    if (fatalMissingKeys.length > 0) {
      return new Response(
        JSON.stringify({
          error: "FIREBASE_CONFIG_MISSING",
          app,
          missing: missingKeys,
          fatalMissing: fatalMissingKeys,
          hint:
            "Set FIREBASE_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_MESSAGING_SENDER_ID and at least one platform App ID (Android or iOS) in Edge Function secrets.",
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    return new Response(
      JSON.stringify({
        app,
        missing: missingKeys,
        android: {
          apiKey,
          appId: androidAppId,
          messagingSenderId,
          projectId,
          storageBucket,
        },
        ios: {
          apiKey,
          appId: iosAppId,
          messagingSenderId,
          projectId,
          storageBucket,
          iosBundleId,
        },
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          "Cache-Control": "no-store",
        },
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: "UNEXPECTED_ERROR",
        message: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});
