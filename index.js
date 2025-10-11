const express = require("express");
const TelegramBot = require("node-telegram-bot-api");

const app = express();
const PORT = process.env.PORT || 3000;

// === TELEGRAM BOT SETUP ===
const TOKEN = "8406972008:AAHTmNluGB3UD6Xmj2HVVB5YAguuj2mWk-k"; // your token
const bot = new TelegramBot(TOKEN, { polling: true });

bot.on("message", (msg) => {
  bot.sendMessage(msg.chat.id, `Hey ${msg.from.first_name}! You said: ${msg.text}`);
});

// === PAYSTACK WEBHOOK ENDPOINT ===
app.use(express.json());
app.post("/paystack/webhook", (req, res) => {
  console.log("Received Paystack webhook:", req.body);
  res.sendStatus(200);
});

// === START SERVER ===
app.listen(PORT, () => console.log(`✅ Server running on port ${PORT}`));
