# How far the current business is from taking bookings, read from its data:
# it needs an active service, an active professional offering it and that
# professional's weekly hours (what makes them bookable). Nothing about the
# setup is stored, so it stays right whatever page the owner used.
class BusinessSetup
  # What the business needs, in order.
  TASKS = %w[service professional hours].freeze
  # The setup assistant's steps: the business's details (optional), the tasks
  # and the end.
  STEPS = [ "details", *TASKS, "done" ].freeze

  def service?
    return @service if defined?(@service)

    @service = Service.active.exists?
  end

  def professional?
    return @professional if defined?(@professional)

    @professional = Professional.active.where(id: ProfessionalService.joins(:service).merge(Service.active).select(:professional_id)).exists?
  end

  def hours?
    return @hours if defined?(@hours)

    @hours = Professional.bookable.exists?
  end

  def done?(task)
    public_send(:"#{task}?")
  end

  def complete?
    TASKS.all? { |task| done?(task) }
  end

  # The first task left, or "done".
  def next_step
    TASKS.find { |task| !done?(task) } || "done"
  end

  # Where the assistant opens: the details for a business that has nothing
  # yet, otherwise the first task left.
  def first_step
    service? ? next_step : "details"
  end
end
