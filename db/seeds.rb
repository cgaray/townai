# frozen_string_literal: true

# This file seeds the database with sample town meeting data.
# Run with: bin/rails db:seed
#
# Seeds are idempotent - safe to run multiple times.

# Only seed in development/test environments
unless Rails.env.development? || Rails.env.test?
  puts "Seeds are only for development/test environments. Skipping."
  exit
end

module Seeds
  TOWNS = [
    { name: "Arlington", slug: "arlington" },
    { name: "Medford", slug: "medford" }
  ].freeze

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

  STATUSES = %w[present present present present present remote absent].freeze

  # Raw action values as they might appear in actual meeting documents
  # These get normalized to our enum values (approved, denied, tabled, continued, none)
  TOPIC_TEMPLATES = [
    { title: "Approval of Minutes", summary: "Review and approval of minutes from the previous meeting.", action: "motion carried unanimously" },
    { title: "Public Comment Period", summary: "Opportunity for residents to address the board on items not on the agenda.", action: nil },
    { title: "Budget Review", summary: "Discussion of the proposed fiscal year budget and department allocations.", action: "deferred to next meeting" },
    { title: "Zoning Amendment Proposal", summary: "Consideration of proposed changes to residential zoning requirements.", action: "laid on the table" },
    { title: "Site Plan Review", summary: "Review of site plans for proposed commercial development.", action: "approved 4-1" },
    { title: "Liquor License Application", summary: "Application for new liquor license for local restaurant.", action: "passed" },
    { title: "Road Improvement Project", summary: "Discussion of upcoming road reconstruction and maintenance schedule.", action: nil },
    { title: "School Renovation Update", summary: "Progress report on elementary school renovation project.", action: nil },
    { title: "Conservation Restriction", summary: "Review of proposed conservation restriction on town-owned land.", action: "accepted" },
    { title: "Tax Classification Hearing", summary: "Annual hearing to set residential and commercial tax rates.", action: "adopted" },
    { title: "Personnel Appointment", summary: "Appointment of new department head position.", action: "approved" },
    { title: "Grant Application", summary: "Authorization to apply for state infrastructure grant.", action: "motion passed 5-0" },
    { title: "Special Permit Request", summary: "Request for special permit for home-based business.", action: "rejected 3-2" },
    { title: "Warrant Article Review", summary: "Review of proposed warrant articles for Town Meeting.", action: "continued to March 15" },
    { title: "Emergency Management Update", summary: "Update on emergency preparedness and response plans.", action: nil },
    { title: "Tree Removal Request", summary: "Request to remove protected trees from private property.", action: "postponed indefinitely" },
    { title: "Historic District Proposal", summary: "Proposal to expand local historic district boundaries.", action: "referred to subcommittee" },
    { title: "Recreation Program Fees", summary: "Discussion of proposed fee changes for recreation programs.", action: "approved as amended" },
    { title: "Stormwater Management", summary: "Review of stormwater management regulations and compliance.", action: nil },
    { title: "Sidewalk Construction", summary: "Proposal for new sidewalk construction on Main Street.", action: "voted in favor" }
  ].freeze

  class << self
    def run
      puts "Seeding database..."

      towns = create_towns
      governing_bodies_by_town = create_governing_bodies(towns)
      people_by_town = create_people(towns)
      attendees_by_body = create_attendees(governing_bodies_by_town, people_by_town)
      create_documents(governing_bodies_by_town, attendees_by_body)
      update_counter_caches
      create_sample_api_calls
      create_admin_user
      create_audit_log_data

      print_summary(towns)
    end

    private

    def create_towns
      puts "Creating towns..."
      TOWNS.map do |town_data|
        Town.find_or_create_by!(slug: town_data[:slug]) do |t|
          t.name = town_data[:name]
        end
      end
    end

    def create_governing_bodies(towns)
      puts "Creating governing bodies..."
      result = {}

      towns.each do |town|
        # Each town gets 6-8 governing bodies
        body_names = GOVERNING_BODIES.sample(rand(6..8))
        result[town.id] = body_names.map do |name|
          GoverningBody.find_or_create_by!(normalized_name: GoverningBody.normalize_name(name), town: town) do |gb|
            gb.name = name
          end
        end
      end

      result
    end

    def create_people(towns)
      puts "Creating people..."
      result = {}

      towns.each do |town|
        result[town.id] = []
        30.times do
          name = random_name
          # Ensure unique names within this town
          while Person.exists?(name: name, town: town)
            name = random_name
          end
          result[town.id] << Person.find_or_create_by!(normalized_name: Person.normalize_name(name), town: town) do |p|
            p.name = name
          end
        end
      end

      result
    end

    def create_attendees(governing_bodies_by_town, people_by_town)
      puts "Creating attendees..."
      result = {}

      governing_bodies_by_town.each_value do |bodies|
        bodies.each do |body|
          town_people = people_by_town[body.town_id]
          member_count = rand(5..9)
          body_members = town_people.sample(member_count)

          result[body.id] = body_members.map do |person|
            Attendee.find_or_create_by!(
              normalized_name: Attendee.normalize_name(person.name),
              governing_body_extracted: body.name
            ) do |a|
              a.name = person.name
              a.person = person
              a.governing_body = body
            end
          end
        end
      end

      result
    end

    def create_documents(governing_bodies_by_town, attendees_by_body)
      puts "Creating documents..."
      documents_created = 0

      governing_bodies_by_town.each_value do |bodies|
        bodies.each do |body|
          meeting_count = rand(6..18)
          # Mix of past and future meetings
          past_dates = (meeting_count - 2).times.map { random_date_in_past }.sort.reverse
          future_dates = 2.times.map { random_date_in_future }.sort
          meeting_dates = past_dates + future_dates

          meeting_dates.each do |date|
            meeting_time = random_time
            attendees_data = build_attendees_data(attendees_by_body[body.id])
            topics = generate_topics
            is_future_meeting = date > Date.current

            # Future meetings: only agenda (meeting hasn't happened yet)
            # Past meetings: always have minutes, sometimes also have agenda (~50%)
            doc_types = if is_future_meeting
              %w[agenda]
            elsif rand < 0.5
              %w[agenda minutes]
            else
              %w[minutes]
            end

            doc_types.each do |doc_type|
              file_name = "#{body.name.parameterize}-#{doc_type}-#{date.strftime('%Y-%m-%d')}.pdf"
              file_hash = Digest::SHA256.hexdigest("#{body.id}-#{file_name}")

              # Skip if document already exists
              next if Document.exists?(source_file_hash: file_hash)

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

              doc = Document.create!(
                source_file_name: file_name,
                source_file_hash: file_hash,
                status: :complete,
                governing_body: body,
                extracted_metadata: metadata.to_json,
                raw_text: "Sample extracted text for #{body.name} #{doc_type} from #{date}."
              )

              create_document_attendees(doc, attendees_by_body[body.id], attendees_data)
              create_document_topics(doc, topics)
              documents_created += 1
            end
          end
        end
      end

      puts "  Created #{documents_created} documents"
    end

    def build_attendees_data(attendees)
      attendees.map.with_index do |attendee, i|
        role = case i
        when 0 then "chair"
        when 1 then "vice-chair"
        when 2 then "clerk"
        else "member"
        end
        status = STATUSES.sample

        {
          "name" => attendee.name,
          "role" => role,
          "status" => status,
          "source_text" => "#{attendee.name}, #{role.capitalize}"
        }
      end
    end

    def create_document_attendees(doc, attendees, attendees_data)
      attendees_data.each do |att_data|
        attendee = attendees.find { |a| a.name == att_data["name"] }
        next unless attendee

        DocumentAttendee.find_or_create_by!(document: doc, attendee: attendee) do |da|
          da.role = att_data["role"]
          da.status = att_data["status"]
          da.source_text = att_data["source_text"]
        end
      end
    end

    def create_document_topics(doc, topics_data)
      topics_data.each_with_index do |topic_data, position|
        raw_action = topic_data[:action_taken]
        Topic.create!(
          document: doc,
          title: topic_data[:title],
          summary: topic_data[:summary],
          action_taken: Topic.normalize_action(raw_action),
          action_taken_raw: raw_action,
          source_text: topic_data[:source_text],
          position: position
        )
      end
    end

    def update_counter_caches
      puts "Updating counter caches..."
      Person.find_each do |person|
        person.update_column(:document_appearances_count, person.document_attendees.count)
      end

      GoverningBody.find_each do |body|
        GoverningBody.reset_counters(body.id, :documents)
      end
    end

    def create_sample_api_calls
      puts "Creating sample API calls..."
      Document.where.not(id: ApiCall.select(:document_id)).limit(20).each do |doc|
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
    end

    def create_admin_user
      puts "Creating admin user..."
      admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
      admin = User.find_or_create_by!(email: admin_email) do |user|
        user.admin = true
      end
      admin.update!(admin: true) # Ensure admin flag is set even if user existed
      puts "  Admin user: #{admin_email}"
      admin
    end

    def create_audit_log_data
      puts "Creating audit log data..."
      admin = User.where(admin: true).first || create_admin_user
      documents = Document.limit(10).to_a
      people = Person.limit(5).to_a
      topics = Topic.limit(10).to_a

      return if documents.empty? || people.empty?

      # Create admin action logs with realistic action/resource combinations
      admin_actions = [
        # User actions
        { action: "user_create", resource_type: "User", new_state: { email: "newuser@example.com", admin: false } },
        { action: "user_update", resource_type: "User", previous_state: { admin: false }, new_state: { admin: true } },
        { action: "user_role_change", resource_type: "User", previous_state: { admin: false }, new_state: { admin: true } },
        { action: "user_delete", resource_type: "User", previous_state: { email: "deleted@example.com", admin: false } },

        # Person actions
        { action: "person_merge", resource_type: "Person", new_state: { source_count: 2, merged_ids: [ 1, 2 ] } },
        { action: "person_unmerge", resource_type: "Person", new_state: { split_into: [ 3, 4 ] } },
        { action: "person_link", resource_type: "Person", new_state: { linked_attendee_id: 5 } },
        { action: "person_unlink", resource_type: "Person", new_state: { unlinked_attendee_id: 5 } },

        # Document actions
        { action: "document_retry", resource_type: "Document", new_state: { status: "pending", reason: "Manual retry" } },
        { action: "document_delete", resource_type: "Document", previous_state: { status: "complete", file_name: "deleted.pdf" } },
        { action: "document_reextract", resource_type: "Document", new_state: { status: "extracting_metadata" } },

        # Topic actions
        { action: "topic_update", resource_type: "Topic", previous_state: { action_taken: "none" }, new_state: { action_taken: "approved" } },
        { action: "topic_delete", resource_type: "Topic", previous_state: { title: "Deleted topic" } }
      ]

      25.times do
        action_template = admin_actions.sample
        resource_id = case action_template[:resource_type]
        when "Document" then documents.sample&.id
        when "Person" then people.sample&.id
        when "User" then admin.id
        when "Topic" then topics.sample&.id
        end

        AdminAuditLog.create!(
          user: admin,
          action: action_template[:action],
          resource_type: action_template[:resource_type],
          resource_id: resource_id,
          ip_address: "192.168.1.#{rand(1..255)}",
          params: nil,
          previous_state: action_template[:previous_state]&.to_json,
          new_state: action_template[:new_state]&.to_json,
          created_at: rand(1..30).days.ago + rand(0..23).hours + rand(0..59).minutes
        )
      end
      puts "  Created #{AdminAuditLog.count} admin audit logs"

      # Create authentication logs with proper user associations
      user_agents = [
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
      ]

      # Successful logins (with user)
      15.times do
        AuthenticationLog.create!(
          user: admin,
          action: "login_success",
          email_hash: nil,
          ip_address: "192.168.1.#{rand(1..255)}",
          user_agent: user_agents.sample,
          created_at: rand(1..30).days.ago + rand(0..23).hours + rand(0..59).minutes
        )
      end

      # Failed logins (no user, but email hash)
      10.times do |i|
        email = "unknown#{i}@example.com"
        AuthenticationLog.create!(
          user: nil,
          action: "login_failed",
          email_hash: AuthenticationLog.hash_email(email),
          ip_address: "192.168.1.#{rand(1..255)}",
          user_agent: user_agents.sample,
          created_at: rand(1..30).days.ago + rand(0..23).hours + rand(0..59).minutes
        )
      end

      # Logouts (with user)
      8.times do
        AuthenticationLog.create!(
          user: admin,
          action: "logout",
          email_hash: nil,
          ip_address: "192.168.1.#{rand(1..255)}",
          user_agent: user_agents.sample,
          created_at: rand(1..30).days.ago + rand(0..23).hours + rand(0..59).minutes
        )
      end

      # Magic link events
      5.times do
        AuthenticationLog.create!(
          user: admin,
          action: "magic_link_used",
          email_hash: nil,
          ip_address: "192.168.1.#{rand(1..255)}",
          user_agent: user_agents.sample,
          created_at: rand(1..30).days.ago + rand(0..23).hours + rand(0..59).minutes
        )
      end
      puts "  Created #{AuthenticationLog.count} authentication logs"

      # Create document event logs
      documents.each do |doc|
        base_time = doc.created_at

        # Upload event
        DocumentEventLog.create!(
          document: doc,
          event_type: "uploaded",
          metadata: { file_size: rand(100_000..5_000_000), content_type: "application/pdf" }.to_json,
          created_at: base_time
        )

        # Extraction started
        DocumentEventLog.create!(
          document: doc,
          event_type: "extraction_started",
          metadata: { job_id: SecureRandom.uuid }.to_json,
          created_at: base_time + rand(1..30).seconds
        )

        # Some documents fail, then retry
        if rand < 0.25
          DocumentEventLog.create!(
            document: doc,
            event_type: "extraction_failed",
            metadata: { error: [ "Failed to parse PDF structure", "Timeout waiting for API response", "Invalid PDF format" ].sample, retry_count: 0 }.to_json,
            created_at: base_time + rand(1..2).minutes
          )

          DocumentEventLog.create!(
            document: doc,
            event_type: "retry",
            metadata: { reason: "Auto-retry after failure", attempt: 1 }.to_json,
            created_at: base_time + rand(3..5).minutes
          )

          DocumentEventLog.create!(
            document: doc,
            event_type: "extraction_completed",
            metadata: { duration_ms: rand(5000..15000), pages: rand(1..20) }.to_json,
            created_at: base_time + rand(6..10).minutes
          )
        else
          # Successful extraction
          DocumentEventLog.create!(
            document: doc,
            event_type: "extraction_completed",
            metadata: { duration_ms: rand(2000..8000), pages: rand(1..20) }.to_json,
            created_at: base_time + rand(1..3).minutes
          )
        end

        # Metadata extraction
        DocumentEventLog.create!(
          document: doc,
          event_type: "metadata_extracted",
          metadata: { topics_count: rand(3..10), attendees_count: rand(5..12) }.to_json,
          created_at: base_time + rand(4..8).minutes
        )
      end
      puts "  Created #{DocumentEventLog.count} document event logs"
    end

    def print_summary(towns)
      puts ""
      puts "=" * 50
      puts "Seed complete!"
      puts "=" * 50
      puts "Created:"
      puts "  - #{User.count} users (#{User.where(admin: true).count} admin)"
      puts "  - #{Town.count} towns"
      towns.each do |town|
        puts "    - #{town.name}: #{town.governing_bodies.count} bodies, #{town.people.count} people, #{town.documents.count} docs"
      end
      puts "  - #{GoverningBody.count} governing bodies"
      puts "  - #{Person.count} people"
      puts "  - #{Attendee.count} attendees"
      puts "  - #{Document.count} documents"
      puts "  - #{Topic.count} topics"
      puts "  - #{DocumentAttendee.count} document attendees"
      puts "  - #{ApiCall.count} API calls"
      puts "  - #{AdminAuditLog.count} admin audit logs"
      puts "  - #{AuthenticationLog.count} authentication logs"
      puts "  - #{DocumentEventLog.count} document event logs"
      puts ""
      puts "Run 'bin/dev' to start the server and view at http://localhost:3000"
    end

    def random_name
      "#{FIRST_NAMES.sample} #{LAST_NAMES.sample}"
    end

    def random_date_in_past(months_back: 24)
      rand(1..months_back).months.ago.to_date - rand(0..27).days
    end

    def random_date_in_future(months_ahead: 3)
      rand(1..months_ahead).months.from_now.to_date + rand(0..14).days
    end

    def random_time
      hour = rand(17..19)
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
  end
end

Seeds.run
