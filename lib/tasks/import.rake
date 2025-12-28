namespace :import do
  desc "Import PDFs from a directory"
  task :directory, [ :path, :limit ] => :environment do |t, args|
    files = Dir.glob("#{args[:path]}/**/*.pdf")
    files = files.first(args[:limit].to_i) if args[:limit].present?

    files.each do |file|
      ImportDocumentJob.perform_later(file)
      puts "Queued: #{file}"
    end
  end
end
