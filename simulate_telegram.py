import asyncio
from aiogram import types
from pouchon_bot import dp  # Dispatcher from your bot

# List your bot commands here
commands = ["/start", "/help", "/your_custom_command"]

async def test_commands():
    for i, cmd in enumerate(commands, start=1):
        update = types.Update(
            update_id=i,
            message=types.Message(
                message_id=i,
                from_user=types.User(id=12345, is_bot=False, first_name="Tester", username="tester"),
                chat=types.Chat(id=12345, type="private"),
                date=None,
                text=cmd
            )
        )
        await dp.process_update(update)
        print(f"Simulated command sent: {cmd}")

asyncio.run(test_commands())o

