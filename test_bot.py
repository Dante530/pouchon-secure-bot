from pouchon_bot import handle_command  # Adjust if your bot has a main handler

# Simulate Telegram commands
commands = [
    "/start",
    "/help",
    "/your_custom_command"
]

for cmd in commands:
    response = handle_command(cmd)  # This should call the same function your bot uses
    print(f"Command: {cmd}\nResponse: {response}\n{'-'*30}")
