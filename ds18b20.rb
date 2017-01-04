# coding: utf-8
#------------------------------------------------------------------------------
# DS18b20温度センサの値を2秒間隔で取得＆アップロードを30回繰り返して終了する。
# Last update: 2017/01/04
# Author: Sho KANEMARU
# usage: $ ruby ds18b20.rb または $ ./ds18b20.sh
#------------------------------------------------------------------------------
require 'json'
require 'net/http'
require 'uri'
require 'base64'
require 'yaml'

#----------------- 設定ファイル読み込み ------------
confFileName = "./config.yml"
config = YAML.load_file(confFileName)

# デバイスID (Cumulocityが払い出したID)
DEVICEID = config["deviceId"]
# CumulocityへのログインID
USERID = config["userId"]
# Cumulocityへのログインパスワード
PASSWD = config["password"]
# GPIOのPIN番号
TEMPFILENAME = config["filename"]
# CumulocityのURL
URL = config["url"] + "/measurement/measurements/"

for i in 1..30 do
  # 測定日時を取得する
  day = Time.now
  time = day.strftime("%Y-%m-%dT%H:%M:%S.000+09:00")

  # 温度データが記録されているファイルを開く
  file = File.open(TEMPFILENAME, "r")

  # 初期化
  temperature = 0.0
  
  # ファイルから温度データを読み取る
  file.each_line do |line|
    #puts "line: #{line}"
    if %r{t=([0-9]+)} =~ line then
      str = $~[1]
      temperature = str.to_f / 1000
      puts "temperature = #{temperature}°C"
    end
  end
  file.close

  # Cumulocityへ送付するデータ(JSON形式)を設定する
  data_magnetic = {
    :DS18b20Measurement => {
      :T => {
        :value => temperature,
        :unit => "C"
      }
    },
    :time => time,
    :source => {
      :id => DEVICEID
    },
    :type => "DS18b20Measurement"
  }

  # URLからURI部分を抽出(パース処理)
  uri = URI.parse(URL)

  # 以降、HTTP送信処理
  https = Net::HTTP.new(uri.host, uri.port)
  #https.set_debug_output $stderr
  https.use_ssl = true # HTTPSを使用

  # httpリクエストヘッダの設定
  initheader = {
    'Content-Type' =>'application/vnd.com.nsn.cumulocity.measurement+json; charset=UTF-8; ver=0.9',
    'Accept'=>'application/vnd.com.nsn.cumulocity.measurement+json; charset=UTF-8; ver=0.9',
    'Authorization'=>'Basic ' + Base64.encode64(USERID + ":" + PASSWD)
  }

  # httpリクエストの生成、送信
  request = Net::HTTP::Post.new(uri.request_uri, initheader)
  payload = JSON.pretty_generate(data_magnetic)
  request.body = payload
  response = https.request(request)

  # API実行結果を画面に表示
  puts "------------------------"
  puts "code -> #{response.code}"
  #puts "msg -> #{response.message}"
  #puts "body -> #{response.body}"

  sleep 1
end
