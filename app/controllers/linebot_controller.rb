class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'selenium-webdriver'
  require 'cgi'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end


  def get_news(escaped_search_word) #スクレイピングを行い、ニュースを取得
    driver = Selenium::WebDriver.for :chrome
    # googlechromeニュースのブラウザ起動
    driver.get('https://news.google.com/search?q=' + escaped_search_word + '&hl=ja&gl=JP&ceid=JP%3Aja')

    # Xpathで指定した要素(ニュースタイトル/リンク)を取得
    news_title = driver.find_elements(:xpath, '//div[@class= "mEaVNd"]/div/h3/a/span')
    news_el = driver.find_elements(:xpath, '//div[@class= "mEaVNd"]/div/h3/a')

    # Xpathで取得した要素のうちタイトル部分のみ抽出しハッシュを作成
    all_news_title = news_title.map{|x| x.text}
    # Xpathで取得した要素のうちリンク部分のみ抽出しハッシュを作成
    all_news_link = news_el.map{|x| x.attribute('href')}

    # タイトルとリンクをそれぞれ対応させる
    all_news_info = all_news_title.zip(all_news_link)

    driver.close
    driver.quit

    return all_news_info
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
    # URIエンコードを行う
    escaped_search_word = CGI.escape(search_word)

    #取得したテキストを元にget_newsアクションを呼び出す
    search_result = get_news(escaped_search_word)



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
                    title: search_result[0][0],
                    text: search_word + 'に関するニュース',
                    actions: [
                      {
                        type: 'uri',
                        label: '記事を読む',
                        uri: search_result[0][1]
                      },
                    ],
                  },
                  {
                    title: search_result[1][0],
                    text: search_word + 'に関するニュース',
                    actions: [
                      {
                        type: 'uri',
                        label: '記事を読む',
                        uri: search_result[1][1]
                      },
                    ],
                  },
                  {
                    title: search_result[2][0],
                    text: search_word + 'に関するニュース',
                    actions: [
                      {
                        type: 'uri',
                        label: '記事を読む',
                        uri: search_result[2][1]
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
