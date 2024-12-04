require "faraday"
require "json"
require "net/http"
require "uri"

class TwitchClient
  BASE_URL = "https://api.twitch.tv/helix"

  def initialize
    @client_id = ENV["TWITCH_CLIENT_ID"]
    @client_secret = ENV["TWITCH_CLIENT_SECRET"]
    @access_token = fetch_access_token
    @connection = Faraday.new(url: BASE_URL) do |faraday|
      faraday.request :url_encoded
      faraday.response :logger, Rails.logger, bodies: true # デバッグ用
      faraday.response :json, content_type: /\bjson$/
      faraday.adapter Faraday.default_adapter
    end
  end

  # アクセストークンを取得またはキャッシュから読み込む
  def fetch_access_token
    Rails.cache.fetch("twitch_access_token", expires_in: 50.minutes) do
      uri = URI("https://id.twitch.tv/oauth2/token")
      params = {
        client_id: @client_id,
        client_secret: @client_secret,
        grant_type: "client_credentials"
      }
      response = Net::HTTP.post_form(uri, params)
      data = JSON.parse(response.body)
      data["access_token"]
    rescue StandardError => e
      Rails.logger.error "Failed to fetch access token: #{e.message}"
      nil
    end
  end

  # 登録者数4万人以上の日本配信者を取得
  def fetch_japanese_streamers(max_results: 50)
    streamers = []
    pagination = nil

    loop do
      remaining = max_results - streamers.size
      break if remaining <= 0

      params = {
        first: [ remaining, 100 ].min,  # 最大100件ずつ取得
        language: "ja"
      }
      params[:after] = pagination if pagination

      response = @connection.get("streams", params) do |req|
        req.headers["Client-ID"] = @client_id
        req.headers["Authorization"] = "Bearer #{@access_token}"
      end

      if response.success?
        data = response.body["data"]
        streamers += data
        pagination = response.body["pagination"]["cursor"]
        break if pagination.nil? || data.empty?
      else
        Rails.logger.error "Twitch API Error: #{response.status} - #{response.body['message']}"
        break
      end
    end

    streamers.first(max_results)
  rescue StandardError => e
    Rails.logger.error "TwitchClient Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    []
  end

  # フォロワー数を取得するメソッド
  def fetch_follower_count(broadcaster_id)
    response = @connection.get("channels/followers") do |req|
      req.params["broadcaster_id"] = broadcaster_id
      req.headers["Client-ID"] = @client_id
      req.headers["Authorization"] = "Bearer #{@access_token}"
    end

    if response.success?
      total_followers = response.body["total"]
      Rails.logger.debug "Total followers for broadcaster ID #{broadcaster_id}: #{total_followers}"
      total_followers
    else
      Rails.logger.error "Failed to fetch follower count for broadcaster ID #{broadcaster_id}: #{response.body['message']}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching follower count: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end

# broadcaster_id: ストリーマーのTwitch ID（文字列）
# max_results: 取得するクリップの最大数（デフォルトは120）
def fetch_clips(broadcaster_id, max_results: 120)
  clips = []
  pagination = nil
  total_clips = 0

  loop do
    remaining = max_results - total_clips
    break if remaining <= 0

    # Twitch APIへのリクエストパラメータ
    params = {
      broadcaster_id: broadcaster_id,
      first: [ remaining, 60 ].min # 最大60件ずつ取得
    }
    params[:after] = pagination if pagination

    begin
      # Twitch APIにリクエスト
      response = @connection.get("clips", params) do |req|
        req.headers["Client-ID"] = @client_id
        req.headers["Authorization"] = "Bearer #{@access_token}"
      end

      if response.success?
        data = response.body["data"]
        Rails.logger.debug "取得したクリップ数: #{data.size}"

        # クリップデータを蓄積
        clips += data

        # 合計取得数を更新
        total_clips += data.size

        # 次のページを設定
        pagination = response.body["pagination"]["cursor"]

        # ページネーションが終了またはデータが空の場合ループを終了
        break if pagination.nil? || data.empty?

        # レート制限を避けるためのスリープ
        sleep(1)
      else
        # APIエラー時のログ
        Rails.logger.error "Twitch API Error: #{response.status} - #{response.body['message']}"
        break
      end
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "Connection failed: #{e.message}"
      retry
    rescue Faraday::TimeoutError => e
      Rails.logger.error "Request timeout: #{e.message}"
      retry
    rescue StandardError => e
      Rails.logger.error "Unexpected error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      break
    end
  end

  # 最終的なクリップデータを返す
  clips
end
  # ゲーム情報を取得するメソッド
  def fetch_game(game_id)
    response = @connection.get("games") do |req|
      req.params["id"] = game_id
      req.headers["Client-ID"] = @client_id
      req.headers["Authorization"] = "Bearer #{@access_token}"
    end

    Rails.logger.debug "Received game response status: #{response.status}"
    Rails.logger.debug "Received game response body: #{response.body}"

    if response.success? && response.body["data"].is_a?(Array) && !response.body["data"].empty?
      response.body["data"].first
    else
      Rails.logger.error "Failed to fetch game with ID #{game_id}: #{response.body['message']}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "TwitchClient fetch_game Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end

  # ユーザープロフィールを取得するメソッド
  def fetch_user_profile(user_id)
    response = @connection.get("users") do |req|
      req.params["id"] = user_id
      req.headers["Client-ID"] = @client_id
      req.headers["Authorization"] = "Bearer #{@access_token}"
    end

    if response.success? && response.body["data"].is_a?(Array) && !response.body["data"].empty?
      response.body["data"].first
    else
      Rails.logger.error "Failed to fetch user profile for user ID #{user_id}: #{response.body['message']}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching user profile: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end

  private

  #
end
