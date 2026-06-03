class DispatchLeadDeliveryJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(lead_delivery_id)
    lead_delivery = LeadDelivery.find(lead_delivery_id)

    Leads::Dispatch::DeliveryExecutor.call(lead_delivery)
  end
end
