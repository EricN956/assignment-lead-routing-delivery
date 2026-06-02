class LeadDelivery < ApplicationRecord
  STATUSES = %w[
    pending
    retrying
    delivered
    duplicate_accepted
    failed
    skipped
  ].freeze

  belongs_to :lead
  belongs_to :recipient

  has_many :dispatch_attempts, dependent: :destroy

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :lead_id, uniqueness: { scope: :recipient_id }
  validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :metadata_must_be_json_object

  scope :pending, -> { where(status: "pending") }
  scope :retryable, -> { where(status: "retrying").where("next_retry_at IS NULL OR next_retry_at <= ?", Time.current) }
  scope :successful, -> { where(status: %w[delivered duplicate_accepted]) }
  scope :failed, -> { where(status: "failed") }

  def successful?
    status.in?(%w[delivered duplicate_accepted])
  end

  def final?
    status.in?(%w[delivered duplicate_accepted failed skipped])
  end

  private

  def metadata_must_be_json_object
    return if metadata.is_a?(Hash)

    errors.add(:metadata, "must be a JSON object")
  end
end
