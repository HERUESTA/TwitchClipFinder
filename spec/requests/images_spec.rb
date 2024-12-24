require 'rails_helper'

RSpec.describe "Images", type: :request do
  describe "GET /ogp" do
    it "returns http success" do
      get "/images/ogp"
      expect(response).to have_http_status(:success)
    end
  end
end
