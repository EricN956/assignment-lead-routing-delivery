module Leads
  class PhoneNormalizer
    def self.call(value)
      new(value).call
    end

    def initialize(value)
      @value = value
    end

    def call
      digits = value.to_s.gsub(/\D/, "")
      digits = digits.delete_prefix("1") if digits.length == 11 && digits.start_with?("1")

      return digits if digits.length == 10

      nil
    end

    private

    attr_reader :value
  end
end
