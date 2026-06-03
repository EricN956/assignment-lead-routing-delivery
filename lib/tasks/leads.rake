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

namespace :leads do
  desc "Run qualification rules for scrubbed leads"
  task qualify: :environment do
    scope = Lead.where(stage: "scrubbed")
    total = scope.count
    qualified = 0
    disqualified = 0
    test_leads = 0
    failed = 0

    scope.find_each do |lead|
      Leads::QualificationProcessor.call(lead)

      case lead.reload.stage
      when "qualified"
        qualified += 1
      when "disqualified"
        disqualified += 1
      when "test"
        test_leads += 1
      end
    rescue StandardError => e
      failed += 1
      lead.record_stage_event!(
        reason: "qualification_failed_unexpectedly",
        metadata: {
          "error_class" => e.class.name,
          "message" => e.message
        }
      )
    end

    puts "Qualification complete"
    puts "total=#{total}"
    puts "qualified=#{qualified}"
    puts "disqualified=#{disqualified}"
    puts "test=#{test_leads}"
    puts "failed=#{failed}"
  end
end

namespace :leads do
  desc "Create recipient delivery records for qualified leads"
  task route: :environment do
    scope = Lead.where(stage: "qualified")
    total = scope.count
    routed = 0
    unroutable = 0
    deliveries = 0
    failed = 0

    scope.find_each do |lead|
      result = Leads::RoutingProcessor.call(lead)

      if result.routed?
        routed += 1
        deliveries += result.deliveries.count
      elsif result.unroutable?
        unroutable += 1
      end
    rescue StandardError => e
      failed += 1
      lead.record_stage_event!(
        reason: "routing_failed_unexpectedly",
        metadata: {
          "error_class" => e.class.name,
          "message" => e.message
        }
      )
    end

    puts "Routing complete"
    puts "total=#{total}"
    puts "routed=#{routed}"
    puts "unroutable=#{unroutable}"
    puts "deliveries=#{deliveries}"
    puts "failed=#{failed}"
  end
end

namespace :leads do
  desc "Enqueue dispatch jobs for pending or retry-ready lead deliveries"
  task dispatch: :environment do
    scope = LeadDelivery
      .where(status: %w[pending retrying])
      .where("next_retry_at IS NULL OR next_retry_at <= ?", Time.current)

    total = scope.count
    enqueued = 0

    scope.find_each do |delivery|
      DispatchLeadDeliveryJob.perform_later(delivery.id)
      enqueued += 1
    end

    puts "Dispatch enqueue complete"
    puts "total=#{total}"
    puts "enqueued=#{enqueued}"
  end
end
