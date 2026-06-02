module Leads
  class ValidationResult
    attr_reader :errors

    def initialize(errors = {})
      @errors = errors.deep_stringify_keys
    end

    def self.valid
      new({})
    end

    def valid?
      errors.blank?
    end

    def invalid?
      !valid?
    end

    def add(field, message)
      key = field.to_s
      errors[key] ||= []
      errors[key] << message
    end

    def to_h
      errors
    end
  end
end
