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
          telegramConnectedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await sendMessage(chatId, "✅ เชื่อม Telegram สำเร็จแล้ว");
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
      disable_web_page_preview: false,
    }),
  });

  const data = await response.json();
  if (!response.ok || !data.ok) {
    throw new Error(`Telegram sendMessage failed: ${JSON.stringify(data)}`);
  }
}

app.post("/send-alert", async (req, res) => {
  try {
    const { uid, lat, lng, type, title, body } = req.body;

    if (!uid || lat == null || lng == null) {
      return res.status(400).json({ ok: false, error: "missing uid/lat/lng" });
    }

    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
      return res.status(404).json({ ok: false, error: "caregiver not found" });
    }

    const data = userSnap.data() || {};
    const chatId = data.telegramChatId;
    const connected = data.telegramConnected === true;

    if (!chatId || !connected) {
      return res.status(400).json({ ok: false, error: "telegram not connected" });
    }

    const mapLink = `https://maps.google.com/?q=${lat},${lng}`;
    const lines = [title || "แจ้งเตือน", body || "", `📍 ${mapLink}`].filter(Boolean);
    const message = lines.join("\n");

    await sendMessage(chatId, message);

    return res.status(200).json({ ok: true });
  } catch (error) {
    console.error("send-alert error", error);
    return res.status(500).json({ ok: false, error: error.message || "send failed" });
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
