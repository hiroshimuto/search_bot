class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'selenium-webdriver'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def get_news(company_name) #スクレイピングを行い、ニュースを取得
    driver = Selenium::WebDriver.for :chrome
 # ブラウザ起動
    driver.get('https://www.yahoo.co.jp/')
    search_box = driver.find_element(:id, 'srchtxt') # 検索欄
    search_btn = driver.find_element(:id, 'srchbtn') # 検索ボタン
    # 入力欄に'Ruby'を入力し、検索ボタンを押下
    search_box.send_keys '#{company_name}'
    search_btn.click

    #ドロップダウンリストからニュースを選択、押下
    dropdown = driver.find_element(:id, 'vmLink') # ドロップダウンリスト
    dropdown.click
    news_btn = driver.find_element(:id, 'news')
    news_btn.click

    # Xpathで指定した要素(ニュースタイトル)を取得
    news_el = driver.find_elements(:xpath, '//div[@id = "NSm"]/div/h2[@class = "t"]/a')
    # Xpathで取得した要素のうちタイトル部分のみ抽出しハッシュを作成
    all_news_title = news_el.map{|x| x.text}
    # Xpathで取得した要素のうちリンク部分のみ抽出しハッシュを作成
    all_news_link = news_el.map{|x| x.attribute('href')}
    # タイトルとリンクをそれぞれ対応させる
    all_news_info = all_news_title.zip(all_news_link)

    all_news_info.each do |news_info|
        news_info = news_info
    end
    return news_info
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end

    #メッセージイベントからテキストの取得
    text_params = params["events"][0]["message"]["text"]
    #取得したメッセージイベントのテキストを元にスクレイピングを実行
    result = get_news(text_params)


    events = client.parse_events_from(body)

    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          message = {
            type: 'template',
            'template': {
              'type': 'carousel',
            },
            text: event.message['text']
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    }

    head :ok
  end
end
