# frozen_string_literal: true

# This file seeds the database with sample town meeting data.
# Run with: bin/rails db:seed
#
# To reset and reseed: bin/rails db:reset

puts "Seeding database..."

# Sample data for realistic town meetings
GOVERNING_BODIES = [
  "Select Board",
  "Planning Board",
  "Zoning Board of Appeals",
  "Conservation Commission",
  "School Committee",
  "Finance Committee",
  "Board of Health",
  "Parks and Recreation Commission",
  "Historical Commission",
  "Library Board of Trustees"
].freeze

FIRST_NAMES = %w[
  James Mary Robert Patricia Michael Jennifer William Linda David Elizabeth
  Richard Barbara Joseph Susan Charles Jessica Thomas Sarah Christopher Karen
  Daniel Nancy Matthew Lisa Mark Betty Donald Sandra Steven Ashley
  Paul Emily Andrew Rebecca Joshua Amanda Kenneth Melissa Kevin Stephanie
].freeze

LAST_NAMES = %w[
  Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez
  Hernandez Lopez Gonzalez Wilson Anderson Thomas Taylor Moore Jackson Martin
  Lee Perez Thompson White Harris Sanchez Clark Ramirez Lewis Robinson
  Walker Young Allen King Wright Scott Torres Nguyen Hill Flores
].freeze

ROLES = %w[chair vice-chair clerk member secretary].freeze
STATUSES = %w[present present present present present remote absent].freeze # Weighted toward present

TOPIC_TEMPLATES = [
  { title: "Approval of Minutes", summary: "Review and approval of minutes from the previous meeting.", action: "approved" },
  { title: "Public Comment Period", summary: "Opportunity for residents to address the board on items not on the agenda.", action: nil },
  { title: "Budget Review", summary: "Discussion of the proposed fiscal year budget and department allocations.", action: "continued" },
  { title: "Zoning Amendment Proposal", summary: "Consideration of proposed changes to residential zoning requirements.", action: "tabled" },
  { title: "Site Plan Review", summary: "Review of site plans for proposed commercial development.", action: "approved" },
  { title: "Liquor License Application", summary: "Application for new liquor license for local restaurant.", action: "approved" },
  { title: "Road Improvement Project", summary: "Discussion of upcoming road reconstruction and maintenance schedule.", action: nil },
  { title: "School Renovation Update", summary: "Progress report on elementary school renovation project.", action: nil },
  { title: "Conservation Restriction", summary: "Review of proposed conservation restriction on town-owned land.", action: "approved" },
  { title: "Tax Classification Hearing", summary: "Annual hearing to set residential and commercial tax rates.", action: "approved" },
  { title: "Personnel Appointment", summary: "Appointment of new department head position.", action: "approved" },
  { title: "Grant Application", summary: "Authorization to apply for state infrastructure grant.", action: "approved" },
  { title: "Special Permit Request", summary: "Request for special permit for home-based business.", action: "denied" },
  { title: "Warrant Article Review", summary: "Review of proposed warrant articles for Town Meeting.", action: "continued" },
  { title: "Emergency Management Update", summary: "Update on emergency preparedness and response plans.", action: nil },
  { title: "Tree Removal Request", summary: "Request to remove protected trees from private property.", action: "tabled" },
  { title: "Historic District Proposal", summary: "Proposal to expand local historic district boundaries.", action: "continued" },
  { title: "Recreation Program Fees", summary: "Discussion of proposed fee changes for recreation programs.", action: "approved" },
  { title: "Stormwater Management", summary: "Review of stormwater management regulations and compliance.", action: nil },
  { title: "Sidewalk Construction", summary: "Proposal for new sidewalk construction on Main Street.", action: "approved" }
].freeze

def random_name
  "#{FIRST_NAMES.sample} #{LAST_NAMES.sample}"
end

def random_date_in_past(months_back: 24)
  Date.today - rand(1..(months_back * 30))
end

def random_time
  hour = rand(17..19) # 5 PM to 7 PM
  minute = [ 0, 30 ].sample
  format("%02d:%02d", hour, minute)
end

def generate_topics(count: rand(4..8))
  TOPIC_TEMPLATES.sample(count).map.with_index do |template, i|
    {
      title: template[:title],
      summary: template[:summary],
      action_taken: template[:action],
      source_text: "Agenda Item #{i + 1}: #{template[:title]}"
    }
  end
end

def generate_abstract(governing_body, doc_type, date)
  if doc_type == "minutes"
    "Minutes of the #{governing_body} meeting held on #{date.strftime('%B %d, %Y')}. " \
    "The board convened to discuss ongoing town matters and take action on pending items."
  else
    "Agenda for the #{governing_body} meeting scheduled for #{date.strftime('%B %d, %Y')}. " \
    "The board will consider several items including regular business and public hearings."
  end
end

# Clear existing data (order matters for foreign keys)
puts "Clearing existing data..."
DocumentAttendee.delete_all
ApiCall.delete_all
Document.delete_all
Attendee.delete_all
Person.delete_all
GoverningBody.delete_all

# Create governing bodies
puts "Creating governing bodies..."
governing_bodies = GOVERNING_BODIES.map do |name|
  GoverningBody.create!(name: name)
end

# Create a pool of people who will be members of various boards
puts "Creating people pool..."
people_pool = 50.times.map do
  name = random_name
  # Ensure unique names
  while Person.exists?(name: name)
    name = random_name
  end
  Person.create!(name: name)
end

# Assign people to governing bodies as attendees
puts "Assigning people to governing bodies..."
attendees_by_body = {}

governing_bodies.each do |body|
  # Each body has 5-9 regular members
  member_count = rand(5..9)
  body_members = people_pool.sample(member_count)

  attendees_by_body[body.id] = body_members.map do |person|
    Attendee.create!(
      name: person.name,
      person: person,
      governing_body: body,
      governing_body_extracted: body.name
    )
  end
end

# Create documents (meetings) for each governing body
puts "Creating documents..."
documents_created = 0

governing_bodies.each do |body|
  # Each body has 6-18 meetings over the past 2 years
  meeting_count = rand(6..18)
  meeting_dates = meeting_count.times.map { random_date_in_past }.sort.reverse

  meeting_dates.each do |date|
    doc_type = %w[agenda minutes minutes].sample # More minutes than agendas
    meeting_time = random_time

    # Generate metadata
    attendees_data = attendees_by_body[body.id].map.with_index do |attendee, i|
      role = i == 0 ? "chair" : (i == 1 ? "vice-chair" : (i == 2 ? "clerk" : "member"))
      status = STATUSES.sample

      {
        "name" => attendee.name,
        "role" => role,
        "status" => status,
        "source_text" => "#{attendee.name}, #{role.capitalize}"
      }
    end

    topics = generate_topics

    metadata = {
      "governing_body" => body.name,
      "document_type" => doc_type,
      "meeting_date" => date.to_s,
      "meeting_time" => meeting_time,
      "abstract" => generate_abstract(body.name, doc_type, date),
      "abstract_source_text" => "Meeting called to order at #{meeting_time}.",
      "attendees" => attendees_data,
      "topics" => topics
    }

    # Create the document
    file_name = "#{body.name.parameterize}-#{doc_type}-#{date.strftime('%Y-%m-%d')}.pdf"

    doc = Document.create!(
      source_file_name: file_name,
      source_file_hash: SecureRandom.hex(32),
      status: :complete,
      governing_body: body,
      extracted_metadata: metadata.to_json,
      raw_text: "Sample extracted text for #{body.name} #{doc_type} from #{date}."
    )

    # Create document_attendees linking attendees to this document
    attendees_data.each do |att_data|
      attendee = attendees_by_body[body.id].find { |a| a.name == att_data["name"] }
      next unless attendee

      DocumentAttendee.create!(
        document: doc,
        attendee: attendee,
        role: att_data["role"],
        status: att_data["status"],
        source_text: att_data["source_text"]
      )
    end

    documents_created += 1
  end
end

# Update counter caches
puts "Updating counter caches..."
Person.find_each do |person|
  person.update_column(:document_appearances_count, person.document_attendees.count)
end

GoverningBody.find_each do |body|
  body.update_column(:documents_count, body.documents.count)
end

# Create some sample API calls
puts "Creating sample API calls..."
Document.limit(20).each do |doc|
  # Text extraction call
  ApiCall.create!(
    document: doc,
    provider: "openrouter",
    model: "anthropic/claude-3.5-sonnet",
    operation: "extract_text",
    status: "success",
    prompt_tokens: rand(100..500),
    completion_tokens: rand(1000..5000),
    total_tokens: rand(1100..5500),
    cost_credits: rand(0.001..0.01).round(6),
    response_time_ms: rand(1000..5000),
    created_at: doc.created_at
  )

  # Metadata extraction call
  ApiCall.create!(
    document: doc,
    provider: "openrouter",
    model: "anthropic/claude-3.5-sonnet",
    operation: "extract_metadata",
    status: "success",
    prompt_tokens: rand(500..2000),
    completion_tokens: rand(500..2000),
    total_tokens: rand(1000..4000),
    cost_credits: rand(0.005..0.02).round(6),
    response_time_ms: rand(2000..8000),
    created_at: doc.created_at + 1.minute
  )
end

# Summary
puts ""
puts "=" * 50
puts "Seed complete!"
puts "=" * 50
puts "Created:"
puts "  - #{GoverningBody.count} governing bodies"
puts "  - #{Person.count} people"
puts "  - #{Attendee.count} attendees"
puts "  - #{Document.count} documents"
puts "  - #{DocumentAttendee.count} document attendees"
puts "  - #{ApiCall.count} API calls"
puts ""
puts "Run 'bin/dev' to start the server and view at http://localhost:3000"
