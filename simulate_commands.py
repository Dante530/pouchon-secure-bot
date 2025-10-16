# simulate_commands.py
import asyncio
from pouchon_bot import handle_message, button_handler, handle_phone, SUBSCRIPTION_PLANS

# ===== Fake Telegram Objects =====
class FakeUser:
    def __init__(self, user_id, first_name="Tester"):
        self.id = user_id
        self.first_name = first_name
        self.is_bot = False

class FakeMessage:
    def __init__(self, text, user):
        self.text = text
        self.from_user = user
        self.chat = type("Chat", (), {"id": user.id, "type": "private"})()
        self.message_id = 1

    async def reply_text(self, text, reply_markup=None):
        print("BOT REPLY:", text)
        if reply_markup:
            print("BOT REPLY MARKUP:", [[btn.text for btn in row] for row in reply_markup.inline_keyboard])

class FakeCallbackQuery:
    def __init__(self, from_user, data, message):
        self.from_user = from_user
        self.data = data
        self.message = message

    async def answer(self):
        print(f"Button '{self.data}' pressed (acknowledged).")

# ===== Fake Context =====
class FakeContext:
    def __init__(self):
        self.user_data = {}

# ===== Simulation Functions =====
async def simulate_command(text, user_id=8273608494):
    user = FakeUser(user_id)
    message = FakeMessage(text, user)
    update = type("Update", (), {"message": message, "effective_user": user})()
    context = FakeContext()
    print(f"Webhook received: {update}")
    await handle_message(update, context)
    return context

async def simulate_button_press(data, context, user_id=8273608494):
    user = FakeUser(user_id)
    fake_msg = FakeMessage("Button pressed", user)
    update_button = FakeCallbackQuery(user, data, fake_msg)
    await update_button.answer()
    await button_handler(update_button, context)

# ===== Run Simulation =====
async def run_bot_for_testing():
    print("⚙️ Starting simulation...")
    # Test /start command
    context = await simulate_command("/start")

    # Simulate selecting a plan (first plan in SUBSCRIPTION_PLANS)
    plan_name = list(SUBSCRIPTION_PLANS.keys())[0]
    context.user_data["pending_plan"] = plan_name
    print(f"User selects plan: {plan_name}")

    # Test button press for MPESA
    await simulate_button_press("kenya", context)

    # Test button press for International card
    await simulate_button_press("intl", context)

    # Test sending a phone number (for MPESA flow)
    class FakePhoneMessage:
        text = "0712345678"
        from_user = FakeUser(8273608494)
        chat = type("Chat", (), {"id": 8273608494, "type": "private"})()
        message_id = 2
    phone_update = type("Update", (), {"message": FakePhoneMessage(), "effective_user": FakePhoneMessage.from_user})()
    await handle_phone(phone_update, context)

# ===== Run =====
if __name__ == "__main__":
    asyncio.run(run_bot_for_testing())
