import os
from fastapi import FastAPI, Request
from telegram import Update
import uvicorn
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Pouchon Bot")

@app.get("/")
async def root():
    return {
        "status": "online", 
        "service": "Pouchon Telegram Bot",
        "timestamp": "2024-01-01T00:00:00Z"
    }

@app.get("/health")
async def health():
    return {"status": "healthy", "bot_token_set": bool(os.getenv("BOT_TOKEN"))}

@app.post("/telegram_webhook")
async def telegram_webhook(request: Request):
    try:
        data = await request.json()
        logger.info(f"Received webhook: {data}")
        return {"ok": True, "message": "Webhook received"}
    except Exception as e:
        logger.error(f"Webhook error: {e}")
        return {"ok": False, "error": str(e)}

@app.post("/paystack_webhook")
async def paystack_webhook(request: Request):
    try:
        data = await request.json()
        logger.info(f"Paystack webhook: {data}")
        return {"status": "success"}
    except Exception as e:
        logger.error(f"Paystack webhook error: {e}")
        return {"status": "error", "message": str(e)}

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    logger.info(f"Starting server on port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")
