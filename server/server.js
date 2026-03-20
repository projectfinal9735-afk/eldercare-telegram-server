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

    const chatId = message.chat.id;
    const text = message.text;

    console.log("Received:", text);

    // ตัวอย่าง: พิมพ์ /start
    if (text === "/start") {
      await sendMessage(chatId, "เชื่อมต่อสำเร็จแล้ว ✅");
    }

    res.sendStatus(200);
  } catch (error) {
    console.error(error);
    res.sendStatus(500);
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