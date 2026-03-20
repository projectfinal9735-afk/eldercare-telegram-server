import express from "express";
import cors from "cors";
import admin from "firebase-admin";

const app = express();
app.use(cors());
app.use(express.json());

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const PORT = process.env.PORT || 3000;

app.get("/", (_req, res) => {
  res.status(200).send("OK");
});

app.post("/telegram-webhook", async (req, res) => {
  try {
    const message = req.body?.message;
    const text = message?.text || "";
    const chatId = message?.chat?.id;

    if (!chatId || !text.startsWith("/start")) {
      return res.sendStatus(200);
    }

    const parts = text.trim().split(" ");
    const payload = parts[1] || "";

    if (!payload.startsWith("caregiver_")) {
      await sendTelegramMessage(chatId, "เชื่อมต่อสำเร็จแล้ว");
      return res.sendStatus(200);
    }

    const caregiverUid = payload.replace("caregiver_", "").trim();
    if (!caregiverUid) {
      await sendTelegramMessage(chatId, "ไม่พบ caregiver uid");
      return res.sendStatus(200);
    }

    await db.collection("users").doc(caregiverUid).set(
      {
        telegramChatId: String(chatId),
        telegramConnected: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await sendTelegramMessage(
      chatId,
      "เชื่อม Telegram สำเร็จแล้ว คุณจะได้รับการแจ้งเตือนจากระบบ"
    );

    return res.sendStatus(200);
  } catch (error) {
    console.error("telegram-webhook error:", error);
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

    if (!Array.isArray(caregiverIds) || caregiverIds.length === 0) {
      return res.status(400).json({ ok: false, error: "caregiverIds required" });
    }

    const mapsUrl =
      lat != null && lng != null
        ? `https://maps.google.com/?q=${lat},${lng}`
        : null;

    const messageLines = [
      `🔔 ${title}`,
      elderName ? `ผู้สูงอายุ: ${elderName}` : null,
      elderId ? `รหัส: ${elderId}` : null,
      type ? `ประเภท: ${type}` : null,
      body || null,
      mapsUrl ? `📍 ตำแหน่ง: ${mapsUrl}` : null,
    ].filter(Boolean);

    const text = messageLines.join("\n");

    const caregiverDocs = await Promise.all(
      caregiverIds.map((id) => db.collection("users").doc(id).get())
    );

    let sent = 0;
    const skipped = [];

    for (const doc of caregiverDocs) {
      if (!doc.exists) {
        skipped.push({ caregiverId: doc.id, reason: "not_found" });
        continue;
      }

      const data = doc.data() || {};
      const chatId = data.telegramChatId;
      const connected = data.telegramConnected === true;

      if (!chatId || !connected) {
        skipped.push({
          caregiverId: doc.id,
          reason: "telegram_not_connected",
        });
        continue;
      }

      await sendTelegramMessage(chatId, text);
      sent += 1;
    }

    return res.json({
      ok: true,
      sent,
      skipped,
    });
  } catch (error) {
    console.error("send-alert error:", error?.response?.data || error);
    return res.status(500).json({
      ok: false,
      error: error?.message || "send-alert failed",
    });
  }
});

async function sendTelegramMessage(chatId, text) {
  const resp = await fetch(
    `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        chat_id: String(chatId),
        text,
      }),
    }
  );

  const data = await resp.json();
  if (!resp.ok || !data.ok) {
    throw new Error(`Telegram send failed: ${JSON.stringify(data)}`);
  }
  return data;
}

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});