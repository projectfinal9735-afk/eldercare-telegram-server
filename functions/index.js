const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');

admin.initializeApp();

const db = admin.firestore();
const telegramBotToken = defineSecret('TELEGRAM_BOT_TOKEN');

function escapeHtml(value = '') {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

async function sendTelegramMessage({ token, chatId, text }) {
  if (!token) {
    throw new Error('Missing TELEGRAM_BOT_TOKEN secret');
  }

  const response = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      parse_mode: 'HTML',
      disable_web_page_preview: false,
    }),
  });

  const payload = await response.json();
  if (!response.ok || !payload.ok) {
    throw new Error(`Telegram send failed: ${JSON.stringify(payload)}`);
  }

  return payload;
}

function eventHeader(type, title) {
  switch (String(type || '').trim()) {
    case 'sos':
      return '🚨 SOS';
    case 'live_started':
      return '📍 เริ่มแชร์ตำแหน่งสด';
    case 'live_stopped':
      return '🛑 หยุดแชร์ตำแหน่งสด';
    case 'manual_pin':
      return '📌 ปักหมุดใหม่';
    case 'manual_input':
      return '🧭 กรอกพิกัดเอง';
    case 'hospital':
      return '🏥 เลือกโรงพยาบาลใกล้ฉัน';
    case 'temple':
      return '🛕 เลือกวัดใกล้ฉัน';
    case 'pharmacy':
      return '💊 เลือกร้านยาใกล้ฉัน';
    case 'restaurant':
      return '🍜 เลือกร้านอาหารใกล้ฉัน';
    case 'cafe':
      return '☕ เลือกร้านคาเฟ่ใกล้ฉัน';
    default:
      return title || '🔔 การแจ้งเตือน';
  }
}

function buildTelegramMessage({ type, title, body, elderName, lat, lng, extra }) {
  const mapLink = `https://www.google.com/maps?q=${lat},${lng}`;
  const poiName = String(extra?.poi_name || '').trim();
  const lines = [
    `<b>${escapeHtml(eventHeader(type, title))}</b>`,
    elderName ? `ผู้สูงอายุ: ${escapeHtml(elderName)}` : null,
    poiName ? `สถานที่: ${escapeHtml(poiName)}` : null,
    body ? escapeHtml(body) : null,
    `พิกัด: ${Number(lat).toFixed(6)}, ${Number(lng).toFixed(6)}`,
    mapLink,
  ];
  return lines.filter(Boolean).join('
');
}

exports.telegramWebhook = onRequest(
  {
    region: 'asia-southeast1',
    secrets: [telegramBotToken],
  },
  async (req, res) => {
    try {
      const update = req.body || {};
      const message = update.message || update.edited_message;
      const text = message?.text || '';
      const chatId = message?.chat?.id;
      const token = telegramBotToken.value();

      if (!chatId || !text.startsWith('/start')) {
        res.status(200).send('ignored');
        return;
      }

      const parts = text.split(' ');
      const payload = (parts[1] || '').trim();
      if (!payload.startsWith('caregiver_')) {
        await sendTelegramMessage({
          token,
          chatId,
          text: 'เชื่อมต่อบอตแล้ว แต่ยังไม่ได้เปิดจากปุ่มเชื่อม Telegram ในแอปผู้ดูแล',
        });
        res.status(200).send('ok');
        return;
      }

      const caregiverUid = payload.replace('caregiver_', '').trim();
      if (!caregiverUid) {
        res.status(200).send('missing uid');
        return;
      }

      await db.collection('users').doc(caregiverUid).set(
        {
          telegramChatId: String(chatId),
          telegramConnected: true,
          telegramConnectedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await sendTelegramMessage({
        token,
        chatId,
        text: 'เชื่อม Telegram กับบัญชีผู้ดูแลสำเร็จแล้ว ✅
หลังจากนี้คุณจะได้รับการแจ้งเตือนจากแอปดูแลผู้สูงอายุ',
      });

      res.status(200).send('ok');
    } catch (error) {
      logger.error('telegramWebhook failed', error);
      res.status(500).send('error');
    }
  }
);

exports.onTelegramNotificationCreated = onDocumentCreated(
  {
    document: 'telegram_notifications/{notificationId}',
    region: 'asia-southeast1',
    secrets: [telegramBotToken],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const elderId = String(data.elderId || '');
    const type = String(data.type || '');
    const title = String(data.title || '');
    const body = String(data.body || '');
    const lat = Number(data.lat);
    const lng = Number(data.lng);
    const extra = data.extra && typeof data.extra === 'object' ? data.extra : {};

    if (!elderId || !Number.isFinite(lat) || !Number.isFinite(lng)) {
      await snap.ref.set(
        {
          status: 'invalid',
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return;
    }

    const elderSnap = await db.collection('users').doc(elderId).get();
    const elder = elderSnap.data() || {};
    const caregiverIds = Array.isArray(elder.caregiverIds) ? elder.caregiverIds.filter(Boolean) : [];
    const elderName = String(elder.fullName || '').trim();
    const token = telegramBotToken.value();

    if (caregiverIds.length === 0) {
      await snap.ref.set(
        {
          status: 'no_caregiver',
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return;
    }

    const caregiverSnaps = await Promise.all(
      caregiverIds.map((uid) => db.collection('users').doc(String(uid)).get())
    );

    const results = [];
    for (const caregiverSnap of caregiverSnaps) {
      const caregiver = caregiverSnap.data() || {};
      const chatId = String(caregiver.telegramChatId || '').trim();
      const caregiverUid = caregiverSnap.id;

      if (!chatId) {
        results.push({ caregiverUid, status: 'missing_chat_id' });
        continue;
      }

      const message = buildTelegramMessage({
        type,
        title,
        body,
        elderName,
        lat,
        lng,
        extra,
      });

      try {
        await sendTelegramMessage({ token, chatId, text: message });
        results.push({ caregiverUid, status: 'sent' });
      } catch (error) {
        logger.error('send telegram failed', { caregiverUid, error: String(error) });
        results.push({ caregiverUid, status: 'failed', error: String(error) });
      }
    }

    await snap.ref.set(
      {
        status: 'processed',
        results,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
);
