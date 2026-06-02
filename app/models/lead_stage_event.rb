class LeadStageEvent < ApplicationRecord
  belongs_to :lead, inverse_of: :stage_events

  validates :to_stage, presence: true, inclusion: { in: Lead::STAGES }
  validates :from_stage, inclusion: { in: Lead::STAGES }, allow_blank: true

  validate :metadata_must_be_json_object

  private

  def metadata_must_be_json_object
    return if metadata.is_a?(Hash)

    errors.add(:metadata, "must be a JSON object")
  end
end
