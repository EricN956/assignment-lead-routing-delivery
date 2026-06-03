module Leads
  module Routing
    Result = Data.define(:lead, :recipients, :deliveries, :unroutable_reason) do
      def routed?
        deliveries.any?
      end

      def unroutable?
        !routed?
      end

      def recipient_codes
        recipients.map(&:code)
      end

      def delivery_ids
        deliveries.map(&:id)
      end

      def to_h
        {
          "recipient_codes" => recipient_codes,
          "delivery_ids" => delivery_ids,
          "unroutable_reason" => unroutable_reason
        }
      end
    end
  end
end
