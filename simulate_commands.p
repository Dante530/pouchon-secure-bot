# simulate_commands.py
import asyncio
from pouchon_bot import handle_message, button_handler

# --- Fake objects to simulate Telegram ---
class FakeUser:
    def __init__(self, user_id):
        self.id = user_id
        self.first_name = "Tester"
        self.is_bot = False

class FakeMessage:
    def __init__(self, text, user):
        self.text = text
        self.from_user = user
        self.chat = type("Chat", (), {"id": user.id, "type": "private"})()
    async def reply_text(self, text, **kwargs):
        print(f"BOT REPLY: {text}")

class FakeCallbackQuery:
    def __init__(self, user, data, message):
        self.from_user = user
        self.data = data
        self.message = message
    async def answer(self):
        print(f"Button '{self.data}' pressed (acknowledged)")

# --- Simulation functions ---
async def simulate_command(command_text="/start"):
    user = FakeUser(8273608494)  # Your admin/test user
    message = FakeMessage(command_text, user)
    # Create a fake Update object
    update = type("Update", (), {"message": message, "effective_user": user})()
    # Fake context object
    context = type("Context", (), {"user_data": {}})()
    print(f"Webhook received: {update}")
    await handle_message(update, context)
    return context

async def simulate_button_press(data, context):
    user = FakeUser(8273608494)
    message = FakeMessage("Button pressed", user)
    fake_query = FakeCallbackQuery(user, data, message)
    # Wrap in fake Update
    fake_update = type("Update", (), {"callback_query": fake_query})()
    await fake_query.answer()
    await button_handler(fake_update, context)

# --- Run all simulations ---
async def run_bot_for_testing():
    print("⚙️ Starting simulation...")
    context = await simulate_command("/start")
    # Simulate button press for Kenya
    await simulate_button_press("kenya", context)
    # Simulate button press for International card
    await simulate_button_press("intl", context)

if __name__ == "__main__":
    asyncio.run(run_bot_for_testing())
