# Picks the locale for pages that don't belong to a business: the one chosen
# in the language switcher (cookie), then the browser's Accept-Language, then
# the default. Business pages override it with the business's locale (see
# SetCurrentBusiness, whose around_action runs inside this one).
module SetLocale
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
  end

  private
    def switch_locale(&action)
      I18n.with_locale(chosen_locale || browser_locale || I18n.default_locale, &action)
    end

    def chosen_locale
      cookies[:locale] if locale_available?(cookies[:locale])
    end

    # "en-US,en;q=0.9,es;q=0.8" -> the first available language by quality.
    def browser_locale
      request.accept_language.to_s.split(",")
        .map { |entry| entry.split(";q=") }
        .sort_by.with_index { |(_, quality), index| [ -(quality || 1).to_f, index ] }
        .map { |(tag, _)| tag.strip.split("-").first.to_s.downcase }
        .find { |language| locale_available?(language) }
    end

    def locale_available?(locale)
      locale.present? && I18n.available_locales.map(&:to_s).include?(locale)
    end
end
