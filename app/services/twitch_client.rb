# app/services/twitch_client.rb

require "faraday"
require "json"

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

  # 日本の配信者を取得するメソッド
  def fetch_japanese_streamers(max_results: 5)
    streamers = []
    pagination = nil

    loop do
      remaining = max_results - streamers.size
      break if remaining <= 0

      params = {
        first: [ remaining, 5 ].min,  # 最大5件ずつ取得
        language: "ja"
      }
      params[:after] = pagination if pagination

      response = @connection.get("streams", params) do |req|
        req.headers["Client-ID"] = @client_id
        req.headers["Authorization"] = "Bearer #{@access_token}"
      end

      Rails.logger.debug "Received response status: #{response.status}"
      Rails.logger.debug "Received response body: #{response.body}"
      Rails.logger.debug "Pagination cursor: #{pagination}"

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

  # ストリーマーのクリップを取得するメソッド
  # broadcaster_id: ストリーマーのTwitch ID（文字列）
  # max_results: 取得するクリップの最大数（デフォルトは20）
  def fetch_clips(broadcaster_id, max_results: 5)
    clips = []
    pagination = nil

    loop do
      remaining = max_results - clips.size
      break if remaining <= 0

      params = {
        broadcaster_id: broadcaster_id,
        first: [ remaining, 5 ].min # 最大5件まで一度に取得可能
      }
      params[:after] = pagination if pagination

      response = @connection.get("clips", params) do |req|
        req.headers["Client-ID"] = @client_id
        req.headers["Authorization"] = "Bearer #{@access_token}"
      end

      Rails.logger.debug "Received response status: #{response.status}"
      Rails.logger.debug "Received response body: #{response.body}"

      if response.success?
        data = response.body["data"]
        clips += data
        pagination = response.body["pagination"]["cursor"]
        break if pagination.nil? || data.empty?
      else
        Rails.logger.error "Twitch API Error: #{response.status} - #{response.body['message']}"
        break
      end
    end

    clips.first(max_results)
  rescue StandardError => e
    Rails.logger.error "TwitchClient Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    []
  end

  # ゲーム情報を取得するメソッド
  # game_id: Twitch のゲーム ID（文字列）
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
end
