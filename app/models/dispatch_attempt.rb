class DispatchAttempt < ApplicationRecord
  belongs_to :lead_delivery

  validates :attempt_number, presence: true,
                             numericality: { only_integer: true, greater_than: 0 },
                             uniqueness: { scope: :lead_delivery_id }
  validates :request_method, presence: true
  validates :request_url, presence: true

  validate :json_columns_must_be_objects

  private

  def json_columns_must_be_objects
    {
      request_headers: request_headers,
      request_body: request_body,
      response_headers: response_headers,
      response_body: response_body
    }.each do |field, value|
      next if value.is_a?(Hash)

      errors.add(field, "must be a JSON object")
    end
  end
end
