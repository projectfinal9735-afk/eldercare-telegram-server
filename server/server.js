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
const LINE_REPLY_FALLBACK_TO_PUSH = String(process.env.LINE_REPLY_FALLBACK_TO_PUSH || "true").trim().toLowerCase() !== "false";
const LINE_API_TIMEOUT_MS = Number(process.env.LINE_API_TIMEOUT_MS || 15000);

app.get("/", (_req, res) => {
  res.status(200).send("LINE server is running");
});

app.get("/health", (_req, res) => {
  res.status(200).json({ ok: true });
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
      const userId = String(event?.source?.userId || "").trim();

      if (event.type === "follow") {
        await sendLineText({
          replyToken: event.replyToken,
          userId,
          text:
            "เพิ่มเพื่อนสำเร็จแล้ว ✅\nหากต้องการเชื่อมบัญชีผู้ดูแล ให้พิมพ์\nLINK caregiver_<uid>\nหรือ\nLINK <uid>",
        });
        continue;
      }

      if (event.type !== "message" || event.message?.type !== "text") {
        console.log(`Skipping non-text event type: ${event.type}`);
        continue;
      }

      const text = String(event.message?.text || "").trim();
      if (!userId || !text) {
        console.log("Skipping event: missing userId or text");
        continue;
      }

      console.log("LINE received:", text, "from", userId);

      const upper = text.toUpperCase();
      if (!upper.startsWith("LINK ")) {
        await sendLineText({
          replyToken: event.replyToken,
          userId,
          text: "รับข้อความแล้ว ✅\nหากต้องการเชื่อมบัญชีผู้ดูแล ให้พิมพ์ LINK caregiver_<uid>",
        });
        continue;
      }

      let caregiverUid = text.substring(5).trim();
      if (!caregiverUid) {
        await sendLineText({
          replyToken: event.replyToken,
          userId,
          text: "รูปแบบไม่ถูกต้อง\nกรุณาพิมพ์ LINK caregiver_<uid>",
        });
        continue;
      }

      if (caregiverUid.toLowerCase().startsWith("caregiver_")) {
        caregiverUid = caregiverUid.substring("caregiver_".length).trim();
      }

      if (!caregiverUid) {
        await sendLineText({
          replyToken: event.replyToken,
          userId,
          text: "ไม่พบ caregiver uid\nกรุณาลองใหม่อีกครั้ง",
        });
        continue;
      }

      const caregiverRef = db.collection("users").doc(caregiverUid);
      const caregiverSnap = await caregiverRef.get();
      if (!caregiverSnap.exists) {
        await sendLineText({
          replyToken: event.replyToken,
          userId,
          text: "ไม่พบบัญชีผู้ดูแลนี้ในระบบ",
        });
        continue;
      }

      await caregiverRef.set(
        {
          lineUserId: userId,
          lineConnected: true,
          lineLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      console.log(`Linked caregiver ${caregiverUid} with LINE user ${userId}`);
      await sendLineText({
        replyToken: event.replyToken,
        userId,
        text: "เชื่อม LINE สำเร็จแล้ว ✅\nหลังจากนี้บัญชีนี้จะได้รับการแจ้งเตือนของผู้สูงอายุ",
      });
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

    const mapsUrl = lat != null && lng != null ? `https://maps.google.com/?q=${lat},${lng}` : null;
    const emoji = type === "sos" ? "🚨" : "🔔";
    const text = [
      `${emoji} ${title}`,
      elderName ? `ผู้สูงอายุ: ${elderName}` : null,
      body || null,
      mapsUrl ? `📍 ตำแหน่ง: ${mapsUrl}` : null,
    ]
      .filter(Boolean)
      .join("\n");

    const caregiverDocs = await Promise.all(
      resolvedCaregiverIds.map(async (id) => ({ id, snap: await db.collection("users").doc(id).get() })),
    );

    await db.collection("line_alert_logs").add({
      elderId: elderId || null,
      elderName: elderName || "",
      caregiverIds: resolvedCaregiverIds,
      type,
      title,
      body,
      lat: lat ?? null,
      lng: lng ?? null,
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
      const lineUserId = data.lineUserId;
      const connected = data.lineConnected === true;

      if (!lineUserId || !connected) {
        skipped.push({ caregiverId: item.id, reason: "line_not_connected" });
        continue;
      }

      await pushMessage(String(lineUserId), text);
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

    await pushMessage(userId, "🔥 test แจ้งเตือน LINE สำเร็จ");
    return res.status(200).send("sent");
  } catch (error) {
    console.error("test-send error:", error?.stack || error);
    return res.status(500).send(error?.message || "error");
  }
});

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
      LINE_REPLY_FALLBACK_TO_PUSH &&
      userId &&
      /Invalid reply token|reply token|400|409/i.test(message);

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

async function callLineApi(url, payload) {
  if (!LINE_CHANNEL_ACCESS_TOKEN) {
    throw new Error("LINE_CHANNEL_ACCESS_TOKEN is missing");
  }

  console.log(`Calling LINE API: ${url}`);
  console.log("LINE payload:", JSON.stringify(payload));

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), LINE_API_TIMEOUT_MS);

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${LINE_CHANNEL_ACCESS_TOKEN}`,
      },
      body: JSON.stringify(payload),
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
});
