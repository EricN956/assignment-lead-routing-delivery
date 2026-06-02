class DispatchAttempt < ApplicationRecord
  include JsonObjectValidatable

  belongs_to :lead_delivery

  validates :attempt_number, presence: true,
                             numericality: { only_integer: true, greater_than: 0 },
                             uniqueness: { scope: :lead_delivery_id }
  validates :request_method, presence: true
  validates :request_url, presence: true

  validates_json_object :request_headers,
                        :request_body,
                        :response_headers,
                        :response_body
end
