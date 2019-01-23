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


  def get_news(search_word) #スクレイピングを行い、ニュースを取得
    driver = Selenium::WebDriver.for :chrome
    # ブラウザ起動
    driver.get('https://www.google.co.jp/')
    search_box = driver.find_element(:name, 'q') # 検索欄
    # 入力欄に'送信されたメッセージ'を入力し、エンターを実行
    search_box.send_keys(search_word, :enter)
    #ニュースボタンが表示されるまで待機
    # wait = Selenium::WebDriver::Wait.new(:timeout => 30)
    # wait.until {driver.find_element(:link_text,'ニュース').displayed?}
    #ニュースボタンを変数に代入
    news_btn = driver.find_element(:link,'ニュース')
    #ニュースボタンをクリック
    news_btn.click

    # Xpathで指定した要素(ニュースタイトル)を取得
    news_el = driver.find_elements(:xpath, "//div[@class = 'g']/div/div/h3/a")
    news_img = driver.find_elements(:xpath, "//div[@class = 'g']/div/a/img")
    # Xpathで取得した要素のうちタイトル部分のみ抽出しハッシュを作成
    all_news_title = news_el.map{|x| x.text}
    # Xpathで取得した要素のうちリンク部分のみ抽出しハッシュを作成
    all_news_link = news_el.map{|x| x.attribute('href')}
    # Xpathで取得したimg要素のうちsrc部分のみ抽出しハッシュを作成
    all_news_img = news_img.map{|x| x.attribute('src')}
    # タイトルとリンクと画像をそれぞれ対応させる
    all_news_info = all_news_title.zip(all_news_link,all_news_img)

    return all_news_info
    driver.quit

    # all_news_info.each do |news_info|
    #     news_info = news_info
    #     return news_info
    # end
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end

    events = client.parse_events_from(body)

    #メッセージイベントからテキストの取得
    search_word = params["events"][0]["message"]["text"]
    #取得したテキストを元にget_newsアクションを呼び出す
    search_result = get_news(search_word)

    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          message = {
            type: 'template',
            altText: 'this is an template message',
            template: {
              type: 'carousel',
              columns: [
                {
                  thumbnailImageUrl: 'https://example.com/image1.jpg',
                  title: search_result[0][0],
                  text: '詳細',
                  actions: [
                    {
                      type: 'uri',
                      label: 'site',
                      uri: 'https://example.com/page1'
                    },
                  ],
                },
                {
                  thumbnailImageUrl: 'https://example.com/image2.jpg',
                  title: search_word,
                  text: '詳細',
                  actions: [
                    {
                      type: 'uri',
                      label: 'site',
                      uri: 'https://example.com/page2'
                    },
                  ],
                },
              ],
            }
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    }

    head :ok
  end
end
