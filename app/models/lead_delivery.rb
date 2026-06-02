class LeadDelivery < ApplicationRecord
  include JsonObjectValidatable

  STATUSES = %w[
    pending
    retrying
    delivered
    duplicate_accepted
    failed
    skipped
  ].freeze

  SUCCESSFUL_STATUSES = %w[delivered duplicate_accepted].freeze
  FINAL_STATUSES = %w[delivered duplicate_accepted failed skipped].freeze

  belongs_to :lead
  belongs_to :recipient

  has_many :dispatch_attempts, dependent: :destroy

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :lead_id, uniqueness: { scope: :recipient_id }
  validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates_json_object :metadata

  scope :pending, -> { where(status: "pending") }
  scope :retryable, -> { where(status: "retrying").where("next_retry_at IS NULL OR next_retry_at <= ?", Time.current) }
  scope :successful, -> { where(status: SUCCESSFUL_STATUSES) }
  scope :failed, -> { where(status: "failed") }

  def successful?
    status.in?(SUCCESSFUL_STATUSES)
  end

  def final?
    status.in?(FINAL_STATUSES)
  end
end
