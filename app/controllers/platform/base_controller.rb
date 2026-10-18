# Base for the platform panel (/platform), where Bookly's own team oversees
# every business. Only for platform admins (User#platform_admin); anyone else
# gets a 404, so the panel doesn't reveal itself. It spans tenants, so reads of
# per-business tables go through BusinessScoped.across_businesses or a
# Current.set(business:) block.
class Platform::BaseController < ApplicationController
  before_action :require_platform_admin

  private
    def require_platform_admin
      raise ActiveRecord::RecordNotFound unless Current.user.platform_admin?
    end
end
