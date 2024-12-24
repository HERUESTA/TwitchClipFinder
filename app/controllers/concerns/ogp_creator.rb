class OgpCreator
  require "mini_magick"
  BASE_IMAGE_PATH = "./app/assets/images/{ black.jpg }"

  def self.build
    image = MiniMagick::Image.open(BASE_IMAGE_PATH)
    image.combine_options do |config|
    end
  end
end
