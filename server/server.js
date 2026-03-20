import express from "express";
import admin from "firebase-admin";

const app = express();
app.use(express.json());

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();
const PORT = process.env.PORT || 3000;

app.post("/telegram-webhook", async (req, res) => {
  try {
    const message = req.body?.message;

    if (!message || !message.text) {
      return res.sendStatus(200);
    }

    const chatId = String(message.chat.id);
    const text = message.text.trim();

    console.log("Received:", text);

    if (!text.startsWith("/start")) {
      return res.sendStatus(200);
    }

    const parts = text.split(" ");
    const payload = parts[1] || "";

    if (!payload.startsWith("caregiver_")) {
      await sendMessage(chatId, "เชื่อมต่อสำเร็จแล้ว ✅");
      return res.sendStatus(200);
    }

    const caregiverUid = payload.replace("caregiver_", "").trim();

    await db.collection("users").doc(caregiverUid).set(
      {
        telegramChatId: chatId,
        telegramConnected: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await sendMessage(chatId, "เชื่อม Telegram สำเร็จแล้ว ✅");
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

    console.log("send-alert payload:", req.body);

    if (!Array.isArray(caregiverIds) || caregiverIds.length === 0) {
      return res.status(400).json({ ok: false, error: "caregiverIds required" });
    }

    const mapsUrl =
      lat != null && lng != null
        ? `https://maps.google.com/?q=${lat},${lng}`
        : null;

    const text = [
      `🔔 ${title}`,
      elderName ? `ผู้สูงอายุ: ${elderName}` : null,
      elderId ? `รหัส: ${elderId}` : null,
      type ? `ประเภท: ${type}` : null,
      body || null,
      mapsUrl ? `📍 ตำแหน่ง: ${mapsUrl}` : null,
    ]
      .filter(Boolean)
      .join("\n");

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
        skipped.push({ caregiverId: doc.id, reason: "telegram_not_connected" });
        continue;
      }

      await sendMessage(String(chatId), text);
      sent += 1;
    }

    return res.json({ ok: true, sent, skipped });
  } catch (error) {
    console.error("send-alert error:", error);
    return res.status(500).json({ ok: false, error: error?.message || "send-alert failed" });
  }
});

async function sendMessage(chatId, text) {
  const token = process.env.TELEGRAM_BOT_TOKEN;

  const resp = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      chat_id: String(chatId),
      text,
    }),
  });

  const data = await resp.json();
  if (!resp.ok || !data.ok) {
    throw new Error(`Telegram send failed: ${JSON.stringify(data)}`);
  }
  return data;
}

app.get("/", (_req, res) => {
  res.send("Server is running 🚀");
});

app.get("/test-send", async (_req, res) => {
  try {
    const chatId = "8589444452";
    await sendMessage(chatId, "🔥 test แจ้งเตือนสำเร็จ");
    res.send("sent");
  } catch (e) {
    console.error("test-send error:", e);
    res.status(500).send("error");
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
