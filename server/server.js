import express from "express";
import fetch from "node-fetch";
import admin from "firebase-admin";

const app = express();
app.use(express.json());

// 🔥 Firebase init
import fs from "fs";
const serviceAccount = JSON.parse(
  fs.readFileSync("./serviceAccountKey.json", "utf8")
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// 🔥 ENV
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;

// ----------------------------
// ✅ Telegram webhook
// ----------------------------
app.post("/telegram-webhook", async (req, res) => {
  const msg = req.body.message;
  if (!msg) return res.sendStatus(200);

  const chatId = msg.chat.id;
  const text = msg.text || "";

  // 👇 รับ start param
  if (text.startsWith("/start caregiver_")) {
    const uid = text.replace("/start caregiver_", "");

    await db.collection("users").doc(uid).update({
      telegramChatId: chatId,
    });

    await sendMessage(chatId, "✅ เชื่อม Telegram สำเร็จแล้ว");
  }

  res.sendStatus(200);
});

// ----------------------------
// ✅ ส่งข้อความ
// ----------------------------
async function sendMessage(chatId, text) {
  await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text,
    }),
  });
}

// ----------------------------
// ✅ API สำหรับส่งแจ้งเตือน
// ----------------------------
app.post("/send-alert", async (req, res) => {
  const { uid, lat, lng, type } = req.body;

  const user = await db.collection("users").doc(uid).get();
  const data = user.data();

  const chatId = data.telegramChatId;
  if (!chatId) return res.status(400).send("No chatId");

  const mapLink = `https://maps.google.com/?q=${lat},${lng}`;

  let text = "";

  if (type === "SOS") {
    text = `🚨 SOS ALERT\n📍 ${mapLink}`;
  } else {
    text = `📍 Location Update\n${mapLink}`;
  }

  await sendMessage(chatId, text);

  res.send("OK");
});

// ----------------------------
app.listen(3000, () => {
  console.log("Server running...");
});