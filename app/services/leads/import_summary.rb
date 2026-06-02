module Leads
  class ImportSummary
    attr_reader :total, :created, :valid, :invalid, :duplicates, :failed, :failures

    def initialize
      @total = 0
      @created = 0
      @valid = 0
      @invalid = 0
      @duplicates = 0
      @failed = 0
      @failures = []
    end

    def increment_total
      @total += 1
    end

    def record_valid
      @created += 1
      @valid += 1
    end

    def record_invalid
      @created += 1
      @invalid += 1
    end

    def record_duplicate
      @duplicates += 1
    end

    def record_failure(identifier:, error:)
      @failed += 1
      failures << {
        "identifier" => identifier,
        "error_class" => error.class.name,
        "message" => error.message
      }
    end

    def to_h
      {
        "total" => total,
        "created" => created,
        "valid" => valid,
        "invalid" => invalid,
        "duplicates" => duplicates,
        "failed" => failed,
        "failures" => failures
      }
    end
  end
end
