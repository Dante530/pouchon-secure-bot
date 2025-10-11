import asyncio
import telegram
from telegram.request import HTTPXRequest

async def test():
    request = HTTPXRequest(connect_timeout=30, read_timeout=30)
    bot = telegram.Bot("8406972008:AAHTmNluGB3UD6Xmj2HVVB5YAguuj2mWk-k", request=request)
    me = await bot.get_me()
    print(me)

asyncio.run(test())
