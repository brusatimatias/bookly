# Which services each professional offers.
class ProfessionalService < ApplicationRecord
  include BusinessScoped

  belongs_to :professional
  belongs_to :service

  validates :service_id, uniqueness: { scope: :professional_id }
end
