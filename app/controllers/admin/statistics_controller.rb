# The business's numbers in a period (?period=, this month by default): owners
# and admins see the whole business, professionals their own. Read through the
# cache (BusinessStats.fetch), so they may be a few minutes old.
class Admin::StatisticsController < Admin::BaseController
  def show
    @period = StatsPeriod.new(params[:period])
    @stats = BusinessStats.fetch(Current.membership, @period) unless without_profile?
  end

  private
    # A professional not linked to a profile has no appointments to count.
    def without_profile?
      !Current.membership.manager? && Current.membership.professional_profile.nil?
    end
end
