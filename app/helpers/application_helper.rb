module ApplicationHelper
  def default_meta_tags
    playlist_title     = @playlist&.title.presence || "Twitchのクリップやプレイリストを共有できるサービス"
    thumbnail_url = @playlist&.clips&.first&.thumbnail_url.presence || image_url("ogp.jpg")

    {
      site: "TwitchClipFinder",
      title: "Twitchのクリップやプレイリストを共有できるサービス",
      reverse: true,
      charset: "utf-8",
      description: "TwitchClipFinderでは他者が作成したクリップやプレイリストを共有することができます",
      keywords: "Twitch,クリップ,ゲーム,ストリーマー,プレイリスト",
      canonical: request.original_url,
      separator: "|",

      # OGP設定
      og: {
        site_name:  "TwitchClipFinder",
        title:      playlist_title,
        description: "TwitchClipFinderでは他者が作成したクリップやプレイリストを共有することができます",
        type:       "website",
        url:        request.original_url,
        image:      thumbnail_url,      # ← 動的にサムネイルを使用
        locale:     "ja-JP"
      },

      # Twitterカード設定
      twitter: {
        card: "summary",
        site: "@siesta985736",
        title: playlist_title,
        image: thumbnail_url            # ← こちらも同じサムネイルを使用
      }
    }
  end
end
