# Records that are never deleted, only deactivated: their history (offered
# services, appointments) stays intact and they can be brought back.
module Deactivatable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(active: true) }
    scope :inactive, -> { where(active: false) }
  end

  def deactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end
end
