class ApplicationController < ActionController::Base
  include Authentication
  include SetLocale

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    # Pages tied to a business are shown in its language, so they don't offer
    # the language switcher.
    def locale_switchable?
      Current.business.nil?
    end
    helper_method :locale_switchable?
end
