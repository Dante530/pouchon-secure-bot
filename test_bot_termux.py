import asyncio
from pouchon_bot import handle_command  # Adjust this to your bot's main message handler

# Simulated commands
commands = [
    "/start",
    "/help",
    "/your_custom_command"  # Replace with your bot's actual commands
]

async def test_commands():
    for cmd in commands:
        # If your handler is async, await it
        if asyncio.iscoroutinefunction(handle_command):
            response = await handle_command(cmd)
        else:
            response = handle_command(cmd)
        print(f"Command: {cmd}\nResponse: {response}\n{'-'*40}")

# Run the test
asyncio.run(test_commands())
