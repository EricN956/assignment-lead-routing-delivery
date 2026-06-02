class Conversion < ApplicationRecord
  DISPOSITIONS = %w[
    signed
    rejected
    not_qualified
    duplicate
    unknown
  ].freeze

  belongs_to :lead
  belongs_to :recipient

  validates :source_claim_id, presence: true
  validates :disposition, presence: true, inclusion: { in: DISPOSITIONS }
  validates :idempotency_key, presence: true, uniqueness: true

  validate :raw_payload_must_be_json_object

  private

  def raw_payload_must_be_json_object
    return if raw_payload.is_a?(Hash)

    errors.add(:raw_payload, "must be a JSON object")
  end
end
