import asyncio
from telegram import Update, Message, Chat, User
from telegram.ext import CallbackContext, ApplicationBuilder
from pouchon_bot import handle_message

async def simulate():
    # Create a dummy bot app
    app = ApplicationBuilder().token("8406972008:AAHTmNluGB3UD6Xmj2HVVB5YAguuj2mWk-k").build()
    bot = app.bot  # actual bot instance

    # Fake user + chat
    fake_user = User(id=8273608494, first_name="Daniel", is_bot=False)
    fake_chat = Chat(id=8273608494, type="private")

    # Create a fake message (without bot)
    fake_message = Message(
        message_id=1,
        date=None,
        chat=fake_chat,
        text="Hi",
        from_user=fake_user
    )

    # Manually link the bot to the message so reply_text() works
    fake_message.set_bot(bot)

    # Fake update and context
    fake_update = Update(update_id=1234, message=fake_message)
    fake_context = CallbackContext(application=app)

    print("📩 Sending fake message to handle_message()...")
    try:
        await handle_message(fake_update, fake_context)
    except Exception as e:
        print("❌ Error in handler:", e)
    print("✅ Simulation complete")

asyncio.run(simulate())
