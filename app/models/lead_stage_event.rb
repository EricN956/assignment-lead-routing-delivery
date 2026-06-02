class LeadStageEvent < ApplicationRecord
  include JsonObjectValidatable

  belongs_to :lead, inverse_of: :stage_events

  validates :to_stage, presence: true, inclusion: { in: Lead::STAGES }
  validates :from_stage, inclusion: { in: Lead::STAGES }, allow_blank: true
  validates_json_object :metadata
end
