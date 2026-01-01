# frozen_string_literal: true

namespace :topics do
  desc "Show topic statistics"
  task stats: :environment do
    puts "Topic Statistics"
    puts "=" * 40
    puts "Total topics: #{Topic.count}"
    puts ""
    puts "By action taken:"
    Topic.group(:action_taken).count.each do |action, count|
      puts "  #{action || 'none'}: #{count}"
    end
    puts ""
    puts "By category:"
    Topic.where.not(category: nil).group(:category).count.each do |cat, count|
      puts "  #{cat}: #{count}"
    end
    if Topic.where(category: nil).any?
      puts "  (uncategorized): #{Topic.where(category: nil).count}"
    end
  end
end
