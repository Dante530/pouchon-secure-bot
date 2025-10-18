import os
from fastapi import FastAPI
import uvicorn

app = FastAPI()

@app.get("/")
async def root():
    return {"status": "online", "message": "Test bot is working!"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.post("/telegram_webhook")
async def telegram_webhook():
    return {"status": "webhook_received"}

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
