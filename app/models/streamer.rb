class Streamer < ApplicationRecord
  has_many :clips, dependent: :destroy
  has_many :follows, dependent: :destroy
  has_many :users, through: :follows

  validates :streamer_id, presence: true, uniqueness: true
  validates :streamer_name, presence: true, uniqueness: true
  validates :display_name, presence: true, uniqueness: true
  validates :profile_image_url, presence: true

  # ransackで検索可能な属性を定義
  def self.ransackable_attributes(auth_object = nil)
    [ "display_name", "streamer_name" ]
  end

  # ransackで検索可能な関連を定義
  def self.ransackable_associations(auth_object = nil)
    [ "clips", "game" ]
  end
end
