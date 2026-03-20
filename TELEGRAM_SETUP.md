# Telegram caregiver notifications

## สิ่งที่มีในชุดนี้
- ปุ่ม `เชื่อม Telegram` ในหน้าโปรไฟล์ผู้ดูแล
- deep link ไปหา Telegram bot พร้อม payload `caregiver_<uid>`
- queue การแจ้งเตือนลง Firestore collection `telegram_notifications`
- Cloud Functions สำหรับรับ `/start` และส่งข้อความไปยังผู้ดูแล
- รองรับ event: SOS, เริ่มแชร์สด, หยุดแชร์สด, ปักหมุด, กรอกพิกัดเอง, โรงพยาบาล, วัด, ร้านยา, ร้านอาหาร, คาเฟ่

## ตั้งค่าก่อนใช้งาน
1. สร้าง bot กับ `@BotFather`
2. แก้ `lib/services/telegram_connect_service.dart`
   - เปลี่ยน `YOUR_BOT_USERNAME` เป็น username บอตจริง (ไม่ต้องมี @)
3. ติดตั้ง dependency ของ Functions
   - `cd functions && npm install`
4. ตั้งค่า secret ของ bot token
   - `firebase functions:secrets:set TELEGRAM_BOT_TOKEN`
5. deploy functions
   - `firebase deploy --only functions`
6. ตั้ง webhook ของ Telegram ให้ชี้ไปที่ฟังก์ชัน `telegramWebhook`

## ตัวอย่างตั้ง webhook
ถ้า URL ของฟังก์ชันคือ:
`https://asia-southeast1-<project-id>.cloudfunctions.net/telegramWebhook`

ให้เปิด:
`https://api.telegram.org/bot<YOUR_TOKEN>/setWebhook?url=https://asia-southeast1-<project-id>.cloudfunctions.net/telegramWebhook`

## การทำงาน
- ผู้ดูแลกด `เชื่อม Telegram` ในแอป
- แอปเปิด Telegram bot พร้อม payload `caregiver_<uid>`
- ผู้ดูแลกด Start
- ฟังก์ชัน `telegramWebhook` จะบันทึก `telegramChatId` และ `telegramConnected=true` ลง `users/{caregiverUid}`
- เมื่อผู้สูงอายุทำ event ใหม่ แอปจะสร้างเอกสารใน `telegram_notifications`
- ฟังก์ชัน `onTelegramNotificationCreated` จะส่งข้อความให้ผู้ดูแลทุกคนที่เชื่อม Telegram สำเร็จ

## หมายเหตุ
- อย่าใส่ bot token ใน Flutter app
- ถ้าเคยเผลอเผย token ให้ revoke ที่ BotFather แล้วออก token ใหม่
- ถ้ายังไม่ deploy functions ปุ่มในแอปจะเปิด Telegram ได้ แต่ `telegramConnected` จะยังไม่เปลี่ยน
