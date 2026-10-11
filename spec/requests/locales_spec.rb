require "rails_helper"

RSpec.describe "Locales", type: :request do
  def lang_of(body)
    body[/<html lang="(\w+)"/, 1]
  end

  describe "pages outside a business" do
    it "default to Spanish" do
      get root_path

      expect(lang_of(response.body)).to eq("es")
    end

    it "follow the browser language" do
      get root_path, headers: { "Accept-Language" => "en-US,en;q=0.9" }

      expect(lang_of(response.body)).to eq("en")
    end

    it "pick the available language the browser prefers most" do
      get root_path, headers: { "Accept-Language" => "fr-FR;q=1.0, es;q=0.5, en;q=0.8" }

      expect(lang_of(response.body)).to eq("en")
    end

    it "fall back to Spanish when the browser asks for other languages" do
      get root_path, headers: { "Accept-Language" => "fr-FR,de;q=0.8" }

      expect(lang_of(response.body)).to eq("es")
    end

    it "show the language switcher" do
      get root_path

      expect(response.body).to include("English", "Español")
    end
  end

  describe "PATCH /locale" do
    it "remembers the chosen language over the browser's" do
      patch locale_path, params: { locale: "en" }, headers: { "HTTP_REFERER" => new_session_url }

      expect(response).to redirect_to(new_session_url)

      get new_session_path, headers: { "Accept-Language" => "es" }
      expect(lang_of(response.body)).to eq("en")
    end

    it "ignores unsupported languages" do
      patch locale_path, params: { locale: "fr" }

      expect(response).to redirect_to(root_path)
      expect(cookies[:locale]).to be_blank
    end
  end

  describe "business pages" do
    it "use the business language regardless of the chosen one" do
      business = create(:business, locale: "es")
      patch locale_path, params: { locale: "en" }

      get business_path(business), headers: { "Accept-Language" => "en" }

      expect(lang_of(response.body)).to eq("es")
      expect(response.body).not_to include("English")
    end
  end
end
