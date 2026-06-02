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
