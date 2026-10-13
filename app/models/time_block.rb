# A period in which a professional can't be booked (vacation, lunch, an
# errand). Blocks of the same professional don't overlap (also enforced by the
# database). Unlike services and professionals they are deleted, not
# deactivated: they carry no history.
class TimeBlock < ApplicationRecord
  include BusinessScoped

  belongs_to :professional

  # Blocks touching the range; one that ends when the range starts doesn't.
  scope :overlapping, ->(range) { where(starts_at: ...range.end).where("ends_at > ?", range.begin) }
  # Ongoing and future blocks, soonest first.
  scope :upcoming, -> { where("ends_at > ?", Time.current).order(:starts_at) }

  normalizes :reason, with: ->(reason) { reason.squish.presence }

  validates :starts_at, :ends_at, presence: true
  validates :reason, length: { maximum: 100 }
  validate :ends_after_start, if: -> { starts_at && ends_at }
  validate :no_overlap, if: -> { professional_id && errors.none? }

  def range
    starts_at...ends_at
  end

  private
    def ends_after_start
      errors.add(:ends_at, :after_start) unless ends_at > starts_at
    end

    def no_overlap
      errors.add(:base, :overlap) if TimeBlock.where(professional_id: professional_id).where.not(id: id).overlapping(range).exists?
    end
end
