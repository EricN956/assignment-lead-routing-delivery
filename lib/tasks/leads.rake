namespace :leads do
  desc "Import inbound leads from a JSON file. Usage: bin/rails leads:ingest FILE=data/inbound_leads.json"
  task ingest: :environment do
    file = ENV.fetch("FILE") do
      raise ArgumentError, "FILE is required. Example: bin/rails leads:ingest FILE=data/inbound_leads.json"
    end

    path = Rails.root.join(file)
    summary = Leads::JsonImporter.call(path)

    puts "Lead import complete"
    summary.to_h.each do |key, value|
      next if key == "failures"

      puts "#{key}=#{value}"
    end

    if summary.failures.any?
      puts "failures:"
      summary.failures.each do |failure|
        puts "- #{failure.fetch("identifier")}: #{failure.fetch("error_class")} #{failure.fetch("message")}"
      end
    end
  end
end

namespace :leads do
  desc "Run DNC suppression check for validated leads"
  task scrub_dnc: :environment do
    scope = Lead.where(stage: "validated")
    total = scope.count
    scrubbed = 0
    suppressed = 0
    failed = 0

    scope.find_each do |lead|
      previous_stage = lead.stage
      Leads::DncScrubber.call(lead)

      case lead.reload.stage
      when "scrubbed"
        scrubbed += 1 if previous_stage == "validated"
      when "suppressed"
        suppressed += 1 if previous_stage == "validated"
      end
    rescue StandardError => e
      failed += 1
      lead.record_stage_event!(
        reason: "dnc_check_failed",
        metadata: {
          "error_class" => e.class.name,
          "message" => e.message
        }
      )
    end

    puts "DNC scrub complete"
    puts "total=#{total}"
    puts "scrubbed=#{scrubbed}"
    puts "suppressed=#{suppressed}"
    puts "failed=#{failed}"
  end
end

namespace :leads do
  desc "Run DNC suppression check for validated leads"
  task scrub_dnc: :environment do
    scope = Lead.where(stage: "validated")
    total = scope.count
    scrubbed = 0
    suppressed = 0
    failed = 0

    scope.find_each do |lead|
      previous_stage = lead.stage
      Leads::DncScrubber.call(lead)

      case lead.reload.stage
      when "scrubbed"
        scrubbed += 1 if previous_stage == "validated"
      when "suppressed"
        suppressed += 1 if previous_stage == "validated"
      end
    rescue StandardError => e
      failed += 1
      lead.record_stage_event!(
        reason: "dnc_check_failed",
        metadata: {
          "error_class" => e.class.name,
          "message" => e.message
        }
      )
    end

    puts "DNC scrub complete"
    puts "total=#{total}"
    puts "scrubbed=#{scrubbed}"
    puts "suppressed=#{suppressed}"
    puts "failed=#{failed}"
  end
end
