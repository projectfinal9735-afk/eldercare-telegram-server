import express from "express";
import admin from "firebase-admin";

const app = express();
app.use(express.json());

// 🔥 ใช้ ENV (สำคัญมาก)
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// 🔥 webhook จาก Telegram
app.post("/telegram-webhook", async (req, res) => {
  try {
    const message = req.body.message;

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

    await admin.firestore().collection("users").doc(caregiverUid).set(
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

app.get("/test-send", async (req, res) => {
  try {
    const chatId = "8589444452"; // ของคุณ
    await sendMessage(chatId, "🔥 test แจ้งเตือนสำเร็จ");
    res.send("sent");
  } catch (e) {
    console.error(e);
    res.send("error");
  }
});

// 🔥 ฟังก์ชันส่งข้อความกลับ
async function sendMessage(chatId, text) {
  const token = process.env.TELEGRAM_BOT_TOKEN;

  await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      chat_id: chatId,
      text: text,
    }),
  });
}

// 🔥 test route
app.get("/", (req, res) => {
  res.send("Server is running 🚀");
});

// 🔥 PORT (Render ใช้ตรงนี้)
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});