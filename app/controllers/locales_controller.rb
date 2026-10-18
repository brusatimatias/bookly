# Language switcher for pages outside a business. Remembers the choice in a
# cookie, which takes precedence over the browser's language (see SetLocale).
class LocalesController < ApplicationController
  allow_unauthenticated_access

  def update
    locale = params[:locale].to_s
    cookies.permanent[:locale] = locale if I18n.available_locales.map(&:to_s).include?(locale)

    redirect_back_or_to root_path
  end
end
