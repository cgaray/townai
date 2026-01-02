# frozen_string_literal: true

# Background job for rebuilding the entire search index.
# This avoids blocking the request thread during the rebuild operation.
class RebuildSearchIndexJob < ApplicationJob
  queue_as :default

  def perform
    SearchIndexer.rebuild_all!
  end
end
