require "rails_helper"

RSpec.describe "I18n" do
  # Flattens {"a" => {"b" => "x"}} into ["a.b"], ignoring the locale root.
  def keys_for(locale)
    Dir[Rails.root.join("config/locales/#{locale}/**/*.yml")].flat_map do |file|
      flatten_keys(YAML.load_file(file).fetch(locale.to_s))
    end.sort
  end

  def flatten_keys(hash, prefix = nil)
    hash.flat_map do |key, value|
      full_key = [ prefix, key ].compact.join(".")
      value.is_a?(Hash) ? flatten_keys(value, full_key) : [ full_key ]
    end
  end

  it "defaults to Spanish and offers Spanish and English" do
    expect(I18n.default_locale).to eq(:es)
    expect(I18n.available_locales).to contain_exactly(:es, :en)
  end

  it "defines the same keys in Spanish and English" do
    expect(keys_for(:es)).to eq(keys_for(:en))
  end

  it "loads Spanish locale data from rails-i18n" do
    expect(I18n.t("errors.messages.blank", locale: :es)).to eq("no puede estar en blanco")
  end
end
