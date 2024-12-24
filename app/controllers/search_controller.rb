# app/controllers/search_controller.rb
class SearchController < ApplicationController
  def index
    @q = Clip.ransack(params[:q])
    @clips = @q.result(distinct: true).includes(:game, :streamer).page(params[:page]).per(60)
    # ログインしている場合のみプレイリストを渡す
    @playlists = user_signed_in? ? current_user.playlists : []
  end

  def playlist
    # プレイリスト取得
    @playlists = Playlist.where(visibility: "public")
  end
end
