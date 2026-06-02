class Lead < ApplicationRecord
  STAGES = %w[
    received
    invalid
    validated
    suppressed
    scrubbed
    disqualified
    qualified
    test
    unroutable
    routed
    dispatched
    delivered
    failed
    converted
    rejected
  ].freeze

  TERMINAL_STAGES = %w[
    invalid
    suppressed
    disqualified
    test
    unroutable
    failed
    converted
    rejected
  ].freeze

  has_many :stage_events,
           class_name: "LeadStageEvent",
           dependent: :destroy,
           inverse_of: :lead

  has_many :lead_deliveries, dependent: :destroy
  has_many :recipients, through: :lead_deliveries
  has_many :dispatch_attempts, through: :lead_deliveries
  has_many :conversions, dependent: :destroy

  validates :source_claim_id, presence: true, uniqueness: true
  validates :publisher, presence: true
  validates :stage, presence: true, inclusion: { in: STAGES }

  after_create :record_initial_stage_event

  scope :by_stage, ->(stage) { where(stage: stage) }
  scope :dispatchable, -> { where(stage: "qualified", test_lead: false) }
  scope :terminal, -> { where(stage: TERMINAL_STAGES) }

  def full_name
    [first_name, last_name].compact_blank.join(" ")
  end

  def terminal?
    TERMINAL_STAGES.include?(stage)
  end

  def transition_to!(to_stage, reason:, metadata: {})
    unless STAGES.include?(to_stage)
      raise ArgumentError, "Unsupported lead stage: #{to_stage}"
    end

    transaction do
      previous_stage = stage

      update!(stage: to_stage)

      stage_events.create!(
        from_stage: previous_stage,
        to_stage: to_stage,
        reason: reason,
        metadata: metadata || {}
      )
    end
  end

  private

  def record_initial_stage_event
    stage_events.create!(
      from_stage: nil,
      to_stage: stage,
      reason: "lead_received",
      metadata: {}
    )
  end
end
