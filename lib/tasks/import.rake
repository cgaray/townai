namespace :import do
  desc "Import PDFs from a directory for a specific town"
  task :directory, [ :town_slug, :path, :limit ] => :environment do |t, args|
    if args[:town_slug].blank? || args[:path].blank?
      puts "Usage: bin/rails import:directory[TOWN_SLUG,PATH,LIMIT]"
      puts "Example: bin/rails import:directory[brookline,/path/to/pdfs,10]"
      puts ""
      puts "Available towns:"
      Town.order(:name).each { |t| puts "  - #{t.slug} (#{t.name})" }
      exit 1
    end

    town = Town.find_by(slug: args[:town_slug])
    unless town
      puts "Error: Town '#{args[:town_slug]}' not found."
      puts ""
      puts "Available towns:"
      Town.order(:name).each { |t| puts "  - #{t.slug} (#{t.name})" }
      exit 1
    end

    files = Dir.glob("#{args[:path]}/**/*.pdf")
    files = files.first(args[:limit].to_i) if args[:limit].present?

    puts "Importing #{files.size} PDFs for #{town.name}..."

    files.each do |file|
      ImportDocumentJob.perform_later(file, town.id)
      puts "Queued: #{file}"
    end
  end
end
