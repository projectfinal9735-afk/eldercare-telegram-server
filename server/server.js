import express from "express";
import fetch from "node-fetch";
import admin from "firebase-admin";

const app = express();
app.use(express.json());

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const PORT = process.env.PORT || 3000;

app.get("/", (_req, res) => {
  res.status(200).send("OK");
});

app.post("/telegram-webhook", async (req, res) => {
  try {
    const msg = req.body.message;
    if (!msg) return res.sendStatus(200);

    const chatId = msg.chat.id;
    const text = msg.text || "";

    if (text.startsWith("/start caregiver_")) {
      const uid = text.replace("/start caregiver_", "").trim();

      await db.collection("users").doc(uid).set(
        {
          telegramChatId: chatId,
          telegramConnected: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await sendMessage(
        chatId,
        "✅ เชื่อม Telegram สำเร็จแล้ว\nจากนี้ระบบจะส่งแจ้งเตือนมาที่แชตนี้"
      );
    }

    return res.sendStatus(200);
  } catch (error) {
    console.error("telegram-webhook error", error);
    return res.sendStatus(200);
  }
});

async function sendMessage(chatId, text) {
  const response = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      disable_web_page_preview: true,
    }),
  });

  const data = await response.json();
  if (!response.ok || !data.ok) {
    throw new Error(`Telegram sendMessage failed: ${response.status} ${JSON.stringify(data)}`);
  }
}

app.post("/send-alert", async (req, res) => {
  try {
    const { elderId, elderName, caregiverIds, type, title, body, lat, lng } = req.body;

    if (!elderId || lat == null || lng == null) {
      return res.status(400).json({ error: "elderId, lat, lng required" });
    }

    const ids = Array.isArray(caregiverIds) ? caregiverIds.filter(Boolean) : [];
    if (ids.length === 0) {
      return res.status(400).json({ error: "caregiverIds required" });
    }

    const mapLink = `https://maps.google.com/?q=${lat},${lng}`;
    const lines = [title || "แจ้งเตือน", body || "", `📍 ${mapLink}`].filter(Boolean);
    if (type) lines.unshift(`ประเภท: ${type}`);
    if (elderName) lines.unshift(`ผู้สูงอายุ: ${elderName}`);
    const message = lines.join("\n");

    const docs = await Promise.all(ids.map((id) => db.collection("users").doc(id).get()));

    let sent = 0;
    const skipped = [];

    for (const doc of docs) {
      const data = doc.data() || {};
      const chatId = data.telegramChatId;
      const connected = data.telegramConnected === true;

      if (!chatId || !connected) {
        skipped.push(doc.id);
        continue;
      }

      await sendMessage(chatId, message);
      sent += 1;
    }

    return res.status(200).json({ ok: true, sent, skipped });
  } catch (error) {
    console.error("send-alert error", error);
    return res.status(500).json({ error: error.message || String(error) });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
