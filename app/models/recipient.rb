class Recipient < ApplicationRecord
  TRANSPORTS = %w[http].freeze
  AUTH_TYPES = %w[none api_key bearer_token custom].freeze

  has_many :lead_deliveries, dependent: :restrict_with_exception
  has_many :leads, through: :lead_deliveries
  has_many :conversions, dependent: :restrict_with_exception

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

  validate :accepted_states_must_be_state_codes
  validate :settings_must_be_json_object

  scope :active, -> { where(active: true) }
  scope :ordered_for_routing, -> { order(priority: :asc, code: :asc) }

  def accepts_state?(state)
    accepted_states.include?(state.to_s.upcase)
  end

  private

  def accepted_states_must_be_state_codes
    return if accepted_states.blank?

    invalid_states = accepted_states.reject { |state| state.to_s.match?(/\A[A-Z]{2}\z/) }
    errors.add(:accepted_states, "must contain 2-letter state codes") if invalid_states.any?
  end

  def settings_must_be_json_object
    return if settings.is_a?(Hash)

    errors.add(:settings, "must be a JSON object")
  end
end
