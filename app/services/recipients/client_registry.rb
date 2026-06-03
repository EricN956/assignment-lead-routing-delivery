module Recipients
  class ClientRegistry
    def self.build(recipient)
      new(recipient).build
    end

    def initialize(recipient)
      @recipient = recipient
    end

    def build
      client_class = recipient.client_class.to_s.safe_constantize

      unless client_class
        raise ClientClassNotFound, "Recipient client class not found: #{recipient.client_class}"
      end

      unless client_class <= BaseClient
        raise ClientClassNotFound, "#{recipient.client_class} must inherit from Recipients::BaseClient"
      end

      client_class.new(recipient: recipient)
    end

    private

    attr_reader :recipient
  end
end
