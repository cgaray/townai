namespace :search do
  desc "Rebuild the entire search index"
  task rebuild: :environment do
    puts "Rebuilding search index..."
    SearchIndexer.rebuild_all!
    puts "Done!"
  end

  desc "Index a single document by ID"
  task :index_document, [ :id ] => :environment do |_t, args|
    document = Document.find(args[:id])
    SearchIndexer.index_document(document)
    puts "Indexed document ##{document.id}"
  end

  desc "Index a single person by ID"
  task :index_person, [ :id ] => :environment do |_t, args|
    person = Person.find(args[:id])
    SearchIndexer.index_person(person)
    puts "Indexed person ##{person.id}"
  end

  desc "Index a single governing body by ID"
  task :index_governing_body, [ :id ] => :environment do |_t, args|
    governing_body = GoverningBody.find(args[:id])
    SearchIndexer.index_governing_body(governing_body)
    puts "Indexed governing body ##{governing_body.id}"
  end

  desc "Show search index stats"
  task stats: :environment do
    sql = "SELECT entity_type, COUNT(*) as count FROM search_entries GROUP BY entity_type ORDER BY entity_type"
    results = ActiveRecord::Base.connection.select_all(sql)

    puts "\nSearch Index Statistics:"
    puts "-" * 30
    total = 0
    results.each do |row|
      puts "#{row['entity_type'].ljust(20)} #{row['count']}"
      total += row["count"]
    end
    puts "-" * 30
    puts "#{'Total'.ljust(20)} #{total}"
  end
end
