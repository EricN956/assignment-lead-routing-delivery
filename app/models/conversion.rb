class Conversion < ApplicationRecord
  include JsonObjectValidatable

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

  validates_json_object :raw_payload
end
