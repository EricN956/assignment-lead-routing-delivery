class Recipient < ApplicationRecord
  include JsonObjectValidatable

  TRANSPORTS = %w[http].freeze
  AUTH_TYPES = %w[none api_key bearer_token custom].freeze

  has_many :lead_deliveries, dependent: :restrict_with_exception
  has_many :leads, through: :lead_deliveries
  has_many :conversions, dependent: :restrict_with_exception

  before_validation :normalize_accepted_states

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :priority, numericality: { only_integer: true }
  validates :daily_cap, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :accepted_states, presence: true
  validates :transport, presence: true, inclusion: { in: TRANSPORTS }
  validates :base_url, presence: true
  validates :endpoint_path, presence: true
  validates :auth_type, presence: true, inclusion: { in: AUTH_TYPES }
  validates :client_class, presence: true

  validates_json_object :settings
  validate :accepted_states_must_be_state_codes

  scope :active, -> { where(active: true) }
  scope :ordered_for_routing, -> { order(priority: :asc, code: :asc) }
  scope :accepting_state, ->(state) { where("? = ANY(accepted_states)", state.to_s.upcase) }

  def accepts_state?(state)
    accepted_states.include?(state.to_s.upcase)
  end

  def endpoint_url
    path = endpoint_path.to_s
    path = "/#{path}" unless path.start_with?("/")

    "#{base_url.to_s.delete_suffix('/')}#{path}"
  end

  def routing_eligible_for?(lead, at: Time.current)
    active? && accepts_state?(lead.accident_state) && !daily_cap_reached?(at: at)
  end

  def daily_cap_reached?(at: Time.current)
    return false if daily_cap.blank?

    lead_deliveries
      .where(status: LeadDelivery::SUCCESSFUL_STATUSES)
      .where(delivered_at: at.all_day)
      .count >= daily_cap
  end

  private

  def normalize_accepted_states
    self.accepted_states = Array(accepted_states)
      .map { |state| state.to_s.strip.upcase }
      .reject(&:blank?)
      .uniq
  end

  def accepted_states_must_be_state_codes
    return if accepted_states.blank?

    invalid_states = accepted_states.reject { |state| state.to_s.match?(/\A[A-Z]{2}\z/) }
    errors.add(:accepted_states, "must contain 2-letter state codes") if invalid_states.any?
  end
end
