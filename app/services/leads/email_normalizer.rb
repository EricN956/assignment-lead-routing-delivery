module Leads
  class EmailNormalizer
    def self.call(value)
      new(value).call
    end

    def initialize(value)
      @value = value
    end

    def call
      normalized = value.to_s.strip.downcase
      normalized.presence
    end

    private

    attr_reader :value
  end
end
