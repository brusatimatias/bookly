# Every business on the platform: a searchable list with a few numbers, each
# business's details and team, and suspending or reactivating it.
class Platform::BusinessesController < Platform::BaseController
  PER_PAGE = 25

  before_action :set_business, only: %i[show suspend reactivate]

  def index
    @query = params[:q].to_s.strip
    @status = params[:status].presence_in(Business.statuses.keys)
    @page = [ params[:page].to_i, 1 ].max

    businesses = filtered_businesses.includes(:owner).order(created_at: :desc, id: :desc)
      .offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    @next_page = businesses.size > PER_PAGE
    @businesses = businesses.first(PER_PAGE)

    ids = @businesses.map(&:id)
    @members_counts = Membership.where(business_id: ids).group(:business_id).count
    @recent_appointments_counts = BusinessScoped.across_businesses do
      Appointment.where(business_id: ids, created_at: 30.days.ago..).group(:business_id).count
    end
  end

  def show
    @memberships = @business.memberships.includes(:user).in_order_of(:role, Membership.roles.keys).order(:created_at)

    Current.set(business: @business) do
      @setup_complete = BusinessSetup.new.complete?
      @stats = {
        services: Service.active.count,
        professionals: Professional.bookable.count,
        customers: Customer.count,
        upcoming: Appointment.active.where(starts_at: Time.current..).count,
        recent: Appointment.where(created_at: 30.days.ago..).count
      }
    end
  end

  def suspend
    @business.suspend! unless @business.suspended?
    redirect_to platform_business_path(@business), notice: t(".suspended", business: @business.name)
  end

  def reactivate
    @business.reactivate! if @business.suspended?
    redirect_to platform_business_path(@business), notice: t(".reactivated", business: @business.name)
  end

  private
    def set_business
      @business = Business.find_by!(slug: params[:id])
    end

    # By name, web address or owner's email; and by status.
    def filtered_businesses
      businesses = Business.all
      businesses = businesses.where(status: @status) if @status

      if @query.present?
        pattern = "%#{Business.sanitize_sql_like(@query)}%"
        owned_by_match = Membership.owner.joins(:user).where(User.arel_table[:email_address].matches(pattern)).select(:business_id)
        businesses = businesses.where(Business.arel_table[:name].matches(pattern))
          .or(businesses.where(Business.arel_table[:slug].matches(pattern)))
          .or(businesses.where(id: owned_by_match))
      end

      businesses
    end
end
