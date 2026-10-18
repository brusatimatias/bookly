# For models whose overlaps are also rejected by an exclusion constraint. The
# validation catches them, but two requests saving at the same time can both
# pass it; the database then rejects the second one, which is reported as the
# same :overlap validation error instead of failing the request.
#
# Each save runs in its own savepoint, so a rejected row doesn't abort an
# outer transaction (WeeklySchedule saves a whole week in one).
module OverlapConstraint
  def save(**options)
    self.class.transaction(requires_new: true) { super(**options) }
  rescue ActiveRecord::ExclusionViolation
    errors.add(:base, :overlap)
    false
  end

  def save!(**options)
    save(**options) || raise(ActiveRecord::RecordInvalid, self)
  end
end
