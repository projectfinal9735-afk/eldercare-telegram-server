import "dotenv/config";
import crypto from "crypto";
import express from "express";
import admin from "firebase-admin";
import fetch from "node-fetch";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(
  express.json({
    verify: (req, _res, buf) => {
      req.rawBody = buf;
    },
  }),
);

function loadServiceAccount() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    return JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  }

  const filePath = path.join(__dirname, "serviceAccountKey.json");
  if (fs.existsSync(filePath)) {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  }

  throw new Error(
    "Missing Firebase credentials. Set FIREBASE_SERVICE_ACCOUNT or provide serviceAccountKey.json",
  );
}

const serviceAccount = loadServiceAccount();
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();
const PORT = Number(process.env.PORT) || 3000;
const HOST = "0.0.0.0";
const LINE_CHANNEL_ACCESS_TOKEN = String(process.env.LINE_CHANNEL_ACCESS_TOKEN || "").trim();
const LINE_CHANNEL_SECRET = String(process.env.LINE_CHANNEL_SECRET || "").trim();
const LINE_REPLY_FALLBACK_TO_PUSH =
  String(process.env.LINE_REPLY_FALLBACK_TO_PUSH || "true").trim().toLowerCase() !== "false";
const LINE_API_TIMEOUT_MS = Number(process.env.LINE_API_TIMEOUT_MS || 15000);
const APP_BASE_URL = String(process.env.APP_BASE_URL || "https://eldercare-telegram-server.onrender.com").trim();

app.get("/", (_req, res) => {
  res.status(200).send("eldercare LINE server is running");
});

app.get("/health", (_req, res) => {
  res.status(200).json({
    ok: true,
    lineAccessTokenConfigured: Boolean(LINE_CHANNEL_ACCESS_TOKEN),
    lineChannelSecretConfigured: Boolean(LINE_CHANNEL_SECRET),
    lineReplyFallbackToPush: LINE_REPLY_FALLBACK_TO_PUSH,
  });
});

app.post("/line-webhook", async (req, res) => {
  try {
    if (!verifyLineSignature(req)) {
      console.error("line-webhook error: invalid signature");
      return res.status(401).send("invalid signature");
    }

    const events = Array.isArray(req.body?.events) ? req.body.events : [];
    console.log(`LINE webhook received ${events.length} event(s)`);

    for (const event of events) {
      await handleLineEvent(event);
    }

    return res.sendStatus(200);
  } catch (error) {
    console.error("line-webhook error:", error?.stack || error);
    return res.sendStatus(500);
  }
});

app.post("/send-alert", async (req, res) => {
  try {
    const {
      elderId,
      elderName,
      caregiverIds = [],
      type = "alert",
      title = "แจ้งเตือน",
      body = "",
      lat,
      lng,
      extra = {},
    } = req.body || {};

    let resolvedCaregiverIds = Array.isArray(caregiverIds)
      ? caregiverIds.map((v) => String(v || "").trim()).filter(Boolean)
      : [];

    if (resolvedCaregiverIds.length === 0 && elderId) {
      const elderSnap = await db.collection("users").doc(String(elderId)).get();
      const elderData = elderSnap.data() || {};
      const raw = elderData.caregiverIds;

      if (Array.isArray(raw)) {
        resolvedCaregiverIds = raw.map((v) => String(v || "").trim()).filter(Boolean);
      } else if (typeof raw === "string" && raw.trim()) {
        resolvedCaregiverIds = [raw.trim()];
      }
    }

    if (resolvedCaregiverIds.length === 0) {
      return res.status(400).json({ ok: false, error: "caregiverIds required" });
    }

    const caregiverDocs = await Promise.all(
      resolvedCaregiverIds.map(async (id) => ({ id, snap: await db.collection("users").doc(id).get() })),
    );

    const text = buildAlertText({ type, title, body, elderName, lat, lng, extra });

    await db.collection("line_alert_logs").add({
      elderId: elderId || null,
      elderName: elderName || "",
      caregiverIds: resolvedCaregiverIds,
      type,
      title,
      body,
      lat: lat ?? null,
      lng: lng ?? null,
      extra: extra || {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    let sent = 0;
    const skipped = [];

    for (const item of caregiverDocs) {
      const doc = item.snap;
      if (!doc.exists) {
        skipped.push({ caregiverId: item.id, reason: "not_found" });
        continue;
      }

      const data = doc.data() || {};
      const lineUserId = String(data.lineUserId || "").trim();
      const connected = data.lineConnected === true;

      if (!lineUserId || !connected) {
        skipped.push({ caregiverId: item.id, reason: "line_not_connected" });
        continue;
      }

      await pushMessage(lineUserId, text);
      sent += 1;
    }

    return res.json({ ok: true, sent, skipped });
  } catch (error) {
    console.error("send-alert error:", error?.stack || error);
    return res.status(500).json({ ok: false, error: error?.message || "send-alert failed" });
  }
});

app.get("/test-send", async (req, res) => {
  try {
    const userId = String(req.query.userId || process.env.LINE_TEST_USER_ID || "").trim();
    if (!userId) {
      return res.status(400).send("set LINE_TEST_USER_ID first or call /test-send?userId=U...");
    }

    await pushMessage(userId, "🔥 ทดสอบแจ้งเตือน LINE สำเร็จ");
    return res.status(200).send("sent");
  } catch (error) {
    console.error("test-send error:", error?.stack || error);
    return res.status(500).send(error?.message || "error");
  }
});

async function handleLineEvent(event) {
  const userId = String(event?.source?.userId || "").trim();

  if (event?.type === "unfollow" && userId) {
    await unlinkByLineUserId(userId);
    console.log(`LINE unfollow: disconnected ${userId}`);
    return;
  }

  if (event?.type === "follow") {
    const profile = userId ? await getLineProfileSafe(userId) : null;
    if (userId && profile) {
      await saveLineProfileToLinkedUsers(userId, profile);
    }

    await sendLineText({
      replyToken: event.replyToken,
      userId,
      text: buildWelcomeText(),
    });
    return;
  }

  if (event?.type !== "message" || event?.message?.type !== "text") {
    console.log(`Skipping non-text event type: ${event?.type}`);
    return;
  }

  const text = String(event.message?.text || "").trim();
  if (!userId || !text) {
    console.log("Skipping event: missing userId or text");
    return;
  }

  console.log("LINE received:", text, "from", userId);

  const profile = await getLineProfileSafe(userId);
  if (profile) {
    await saveLineProfileToLinkedUsers(userId, profile);
  }

  const normalized = text.trim();
  const upper = normalized.toUpperCase();

  if (upper === "HELP" || upper === "MENU" || normalized === "เมนู" || normalized === "ช่วยเหลือ") {
    await sendLineText({ replyToken: event.replyToken, userId, text: buildWelcomeText() });
    return;
  }

  if (upper === "STATUS" || normalized === "สถานะ") {
    const statusText = await buildStatusText(userId);
    await sendLineText({ replyToken: event.replyToken, userId, text: statusText });
    return;
  }

  if (upper === "UNLINK" || normalized === "ยกเลิกเชื่อม" || normalized === "ยกเลิกเชื่อมต่อ") {
    const count = await unlinkByLineUserId(userId);
    await sendLineText({
      replyToken: event.replyToken,
      userId,
      text:
        count > 0
          ? "ยกเลิกเชื่อมต่อ LINE แล้ว ✅\nหากต้องการเชื่อมใหม่ ให้พิมพ์ LINK caregiver_<uid>"
          : "ยังไม่พบบัญชีผู้ดูแลที่เชื่อมกับ LINE นี้",
    });
    return;
  }

  if (!upper.startsWith("LINK ")) {
    await sendLineText({
      replyToken: event.replyToken,
      userId,
      text:
        "รับข้อความแล้ว ✅\nหากต้องการเชื่อมบัญชีผู้ดูแล ให้พิมพ์ LINK caregiver_<uid>\nพิมพ์ STATUS เพื่อตรวจสอบสถานะ",
    });
    return;
  }

  let caregiverUid = normalized.substring(5).trim();
  if (caregiverUid.toLowerCase().startsWith("caregiver_")) {
    caregiverUid = caregiverUid.substring("caregiver_".length).trim();
  }

  if (!caregiverUid) {
    await sendLineText({
      replyToken: event.replyToken,
      userId,
      text: "รูปแบบไม่ถูกต้อง\nกรุณาพิมพ์ LINK caregiver_<uid>",
    });
    return;
  }

  const linkResult = await linkCaregiverLine({ caregiverUid, userId, profile });
  await sendLineText({ replyToken: event.replyToken, userId, text: linkResult.message });
}

async function linkCaregiverLine({ caregiverUid, userId, profile }) {
  const caregiverRef = db.collection("users").doc(caregiverUid);
  const caregiverSnap = await caregiverRef.get();
  if (!caregiverSnap.exists) {
    return { ok: false, message: "ไม่พบบัญชีผู้ดูแลนี้ในระบบ" };
  }

  const caregiverData = caregiverSnap.data() || {};
  if (String(caregiverData.role || "") !== "caregiver") {
    return { ok: false, message: "บัญชีนี้ไม่ใช่ผู้ดูแล" };
  }

  const displayName = String(caregiverData.fullName || caregiverData.identifier || caregiverUid).trim();

  await caregiverRef.set(
    {
      lineUserId: userId,
      lineConnected: true,
      lineLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
      lineLastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(profile
        ? {
            lineDisplayName: profile.displayName || null,
            lineLanguage: profile.language || null,
            linePictureUrl: profile.pictureUrl || null,
          }
        : {}),
    },
    { merge: true },
  );

  console.log(`Linked caregiver ${caregiverUid} with LINE user ${userId}`);
  return {
    ok: true,
    message: `เชื่อม LINE สำเร็จแล้ว ✅\nผู้ดูแล: ${displayName}\nหลังจากนี้บัญชีนี้จะได้รับการแจ้งเตือนของผู้สูงอายุ`,
  };
}

async function buildStatusText(userId) {
  const snaps = await db.collection("users").where("lineUserId", "==", userId).limit(5).get();
  if (snaps.empty) {
    return "LINE นี้ยังไม่ได้เชื่อมกับบัญชีผู้ดูแล\nหากต้องการเชื่อม ให้พิมพ์ LINK caregiver_<uid>";
  }

  const names = snaps.docs
    .map((doc) => {
      const data = doc.data() || {};
      return String(data.fullName || data.identifier || doc.id).trim();
    })
    .filter(Boolean);

  return `เชื่อมต่อแล้ว ✅\nบัญชีผู้ดูแล: ${names.join(", ")}\nหากต้องการยกเลิกเชื่อมต่อ ให้พิมพ์ UNLINK`;
}

async function unlinkByLineUserId(lineUserId) {
  const snaps = await db.collection("users").where("lineUserId", "==", lineUserId).get();
  if (snaps.empty) {
    return 0;
  }

  const batch = db.batch();
  for (const doc of snaps.docs) {
    batch.set(
      doc.ref,
      {
        lineConnected: false,
        lineUserId: admin.firestore.FieldValue.delete(),
        lineDisplayName: admin.firestore.FieldValue.delete(),
        lineLanguage: admin.firestore.FieldValue.delete(),
        linePictureUrl: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
  await batch.commit();
  return snaps.size;
}

async function saveLineProfileToLinkedUsers(lineUserId, profile) {
  const snaps = await db.collection("users").where("lineUserId", "==", lineUserId).limit(5).get();
  if (snaps.empty) {
    return;
  }

  const batch = db.batch();
  for (const doc of snaps.docs) {
    batch.set(
      doc.ref,
      {
        lineDisplayName: profile.displayName || null,
        lineLanguage: profile.language || null,
        linePictureUrl: profile.pictureUrl || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
  await batch.commit();
}

function buildWelcomeText() {
  return [
    "สวัสดีจาก ElderCare LINE OA 👋",
    "หากต้องการเชื่อมบัญชีผู้ดูแล ให้พิมพ์",
    "LINK caregiver_<uid>",
    "",
    "คำสั่งที่ใช้ได้:",
    "• STATUS ตรวจสอบสถานะการเชื่อม",
    "• UNLINK ยกเลิกเชื่อมต่อ",
  ].join("\n");
}

function buildAlertText({ type, title, body, elderName, lat, lng, extra }) {
  const mapsUrl = lat != null && lng != null ? `https://maps.google.com/?q=${lat},${lng}` : null;
  const safeExtra = extra && typeof extra === "object" ? extra : {};

  const detailLines = [];
  if (safeExtra.poi_name) {
    detailLines.push(`📍 จุดหมาย: ${safeExtra.poi_name}`);
  }
  if (safeExtra.geofence_name) {
    detailLines.push(`🛡 พื้นที่: ${safeExtra.geofence_name}`);
  }
  if (safeExtra.distance_meters != null) {
    detailLines.push(`📏 ระยะห่าง: ${safeExtra.distance_meters} เมตร`);
  }

  const emojiByType = {
    sos: "🚨",
    geofence_exit: "🚧",
    geofence_enter: "✅",
    live_stopped: "🛑",
  };

  const emoji = emojiByType[type] || "🔔";
  const text = [
    `${emoji} ${title || "แจ้งเตือน"}`,
    elderName ? `ผู้สูงอายุ: ${elderName}` : null,
    body || null,
    ...detailLines,
    mapsUrl ? `🗺 แผนที่: ${mapsUrl}` : null,
  ]
    .filter(Boolean)
    .join("\n");

  return text.slice(0, 4500);
}

function verifyLineSignature(req) {
  if (!LINE_CHANNEL_SECRET) {
    return true;
  }

  const signature = req.get("x-line-signature");
  if (!signature || !req.rawBody) {
    return false;
  }

  const digest = crypto.createHmac("sha256", LINE_CHANNEL_SECRET).update(req.rawBody).digest("base64");
  return digest === signature;
}

async function getLineProfileSafe(userId) {
  try {
    if (!userId || !LINE_CHANNEL_ACCESS_TOKEN) {
      return null;
    }

    const responseText = await callLineApi(`https://api.line.me/v2/bot/profile/${userId}`, null, "GET");
    return responseText ? JSON.parse(responseText) : null;
  } catch (error) {
    console.log("LINE profile fetch skipped:", error?.message || error);
    return null;
  }
}

async function sendLineText({ replyToken, userId, text }) {
  const safeText = String(text || "").trim();
  if (!safeText) {
    return;
  }

  try {
    if (replyToken) {
      await replyMessage(replyToken, safeText);
      console.log("LINE reply success");
      return;
    }
  } catch (error) {
    const message = error?.message || String(error);
    console.error("replyMessage failed:", message);
    const shouldFallback =
      LINE_REPLY_FALLBACK_TO_PUSH && userId && /Invalid reply token|reply token|400|409/i.test(message);

    if (!shouldFallback) {
      throw error;
    }

    console.log("Falling back to push message");
  }

  if (userId && LINE_REPLY_FALLBACK_TO_PUSH) {
    await pushMessage(userId, safeText);
    console.log("LINE push fallback success");
    return;
  }

  throw new Error("Unable to send LINE message: missing replyToken and fallback disabled or missing userId");
}

async function replyMessage(replyToken, text) {
  if (!replyToken) {
    throw new Error("replyToken is missing");
  }

  return callLineApi("https://api.line.me/v2/bot/message/reply", {
    replyToken,
    messages: [{ type: "text", text }],
  });
}

async function pushMessage(userId, text) {
  return callLineApi("https://api.line.me/v2/bot/message/push", {
    to: String(userId),
    messages: [{ type: "text", text }],
  });
}

async function callLineApi(url, payload, method = "POST") {
  if (!LINE_CHANNEL_ACCESS_TOKEN) {
    throw new Error("LINE_CHANNEL_ACCESS_TOKEN is missing");
  }

  console.log(`Calling LINE API: ${url}`);
  if (payload) {
    console.log("LINE payload:", JSON.stringify(payload));
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), LINE_API_TIMEOUT_MS);

  try {
    const response = await fetch(url, {
      method,
      headers: {
        Authorization: `Bearer ${LINE_CHANNEL_ACCESS_TOKEN}`,
        ...(method !== "GET" ? { "Content-Type": "application/json" } : {}),
      },
      ...(payload ? { body: JSON.stringify(payload) } : {}),
      signal: controller.signal,
    });

    const responseText = await response.text();
    console.log(`LINE API status: ${response.status}`);
    if (responseText) {
      console.log(`LINE API body: ${responseText}`);
    }

    if (!response.ok) {
      throw new Error(`LINE API failed: ${response.status} ${responseText}`);
    }

    return responseText;
  } catch (error) {
    if (error?.name === "AbortError") {
      throw new Error(`LINE API timeout after ${LINE_API_TIMEOUT_MS}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

app.listen(PORT, HOST, () => {
  console.log(`Server running on http://${HOST}:${PORT}`);
  console.log(`LINE access token configured: ${LINE_CHANNEL_ACCESS_TOKEN ? "yes" : "no"}`);
  console.log(`LINE channel secret configured: ${LINE_CHANNEL_SECRET ? "yes" : "no"}`);
  console.log(`LINE reply fallback to push: ${LINE_REPLY_FALLBACK_TO_PUSH ? "enabled" : "disabled"}`);
  console.log(`LINE API timeout: ${LINE_API_TIMEOUT_MS}ms`);
  console.log(`APP_BASE_URL: ${APP_BASE_URL}`);
});
