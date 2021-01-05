from selenium import webdriver
from webdriver_manager.chrome import ChromeDriverManager
import telegram
import requests
options = webdriver.ChromeOptions()
options.add_argument("--headless")
options.add_argument("--log-level=3")
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(ChromeDriverManager().install(),options=options)
driver.get("https://www.google.com/")
driver.save_screenshot('driver.png')

data=requests.get("https://msbauthentication.com/autocontrol/api/readtelegram.php")
data=data.json()
def telegram_bot_sendimage(image_url,purpose_id,phone,msg):
    try:
        purpose_id = int(purpose_id)
        #for i in range(purpose_id):  
        if purpose_id == 1:
            bot=telegram.Bot(token=data[0]["api_token"])
            chat_id=data[0]["chat_id"].split(',')
            print(chat_id)
            for i in range(0,len(chat_id)):
                bot.send_photo(chat_id=chat_id[i],photo=open(image_url, 'rb'),caption=str(phone)+':'+msg)
        
        if purpose_id == 2:
            bot=telegram.Bot(token=data[1]["api_token"])
            chat_id=data[1]["chat_id"].split(',')
            print(chat_id)
            for i in range(0,len(chat_id)):
                bot.send_photo(chat_id=chat_id[i],photo=open(image_url, 'rb'),caption=str(phone)+':'+msg)
    except Exception as e:
        print("error",e)
telegram_bot_sendimage("driver.png",2,"9493928782","test from linode")