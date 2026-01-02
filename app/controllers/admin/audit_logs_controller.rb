module Admin
  class AuditLogsController < BaseController
    include Pagy::Backend

    def admin_logs
      scope = AdminAuditLog.includes(:user)

      # Apply filters BEFORE pagination
      scope = apply_admin_filters(scope)

      # Apply sorting
      scope = apply_admin_sorting(scope)

      @pagy, @logs = pagy(scope, items: 50)

      # Compute filter counts for pills
      @filter_counts = admin_log_filter_counts
    end

    def authentication_logs
      scope = AuthenticationLog.includes(:user)

      # Apply filters BEFORE pagination
      scope = apply_auth_filters(scope)

      # Apply sorting
      scope = apply_auth_sorting(scope)

      @pagy, @logs = pagy(scope, items: 50)

      # Compute filter counts for pills
      @filter_counts = auth_log_filter_counts
    end

    def document_events
      scope = DocumentEventLog.includes(document: :governing_body)

      # Apply filters BEFORE pagination
      scope = apply_doc_event_filters(scope)

      # Apply sorting
      scope = apply_doc_event_sorting(scope)

      @pagy, @logs = pagy(scope, items: 50)

      # Compute filter counts for pills
      @filter_counts = doc_event_filter_counts

      # For dropdowns
      @governing_bodies = GoverningBody.joins(:documents).distinct.order(:name)
      @event_types = DocumentEventLog::EVENT_TYPES
    end

    private

    # Admin logs filters (applied before pagination)
    def apply_admin_filters(scope)
      scope = filter_by_action_category(scope) if params[:action_type].present?
      scope = filter_by_user(scope) if params[:user_id].present?
      scope = filter_by_date_range(scope)
      scope
    end

    def filter_by_action_category(scope)
      case params[:action_type]
      when "user" then scope.where("action LIKE 'user_%'")
      when "person" then scope.where("action LIKE 'person_%'")
      when "document" then scope.where("action LIKE 'document_%'")
      else scope.where(action: params[:action_type])
      end
    end

    def filter_by_user(scope)
      user = User.find_by(id: params[:user_id])
      user ? scope.by_user(user) : scope.none
    end

    # Auth logs filters
    def apply_auth_filters(scope)
      scope = filter_auth_by_status(scope) if params[:status].present?
      scope = filter_by_date_range(scope)
      scope
    end

    def filter_auth_by_status(scope)
      case params[:status]
      when "success" then scope.successful
      when "failed" then scope.failed
      else scope
      end
    end

    # Document event filters
    def apply_doc_event_filters(scope)
      scope = filter_doc_by_status(scope) if params[:status].present?
      scope = filter_doc_by_event_type(scope) if params[:event_type].present?
      scope = filter_doc_by_document(scope) if params[:document_id].present?
      scope = filter_doc_by_governing_body(scope) if params[:governing_body_id].present?
      scope = filter_by_date_range(scope)
      scope
    end

    def filter_doc_by_status(scope)
      case params[:status]
      when "success" then scope.successful
      when "failed" then scope.failed
      else scope
      end
    end

    def filter_doc_by_event_type(scope)
      scope.where(event_type: params[:event_type])
    end

    def filter_doc_by_document(scope)
      doc = Document.find_by(id: params[:document_id])
      doc ? scope.where(document: doc) : scope.none
    end

    def filter_doc_by_governing_body(scope)
      body = GoverningBody.find_by(id: params[:governing_body_id])
      body ? scope.joins(:document).where(documents: { governing_body_id: body.id }) : scope.none
    end

    # Shared date range filter
    def filter_by_date_range(scope)
      start_date = parse_date(params[:start_date])
      end_date = parse_date(params[:end_date])

      if start_date && end_date
        scope.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      elsif start_date
        scope.where("created_at >= ?", start_date.beginning_of_day)
      elsif end_date
        scope.where("created_at <= ?", end_date.end_of_day)
      else
        scope
      end
    end

    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string)
    rescue ArgumentError
      nil
    end

    # Sorting methods
    def apply_admin_sorting(scope)
      column = params[:sort]&.to_sym
      direction = params[:direction] == "asc" ? "ASC" : "DESC"

      case column
      when :created_at
        scope.order(Arel.sql("admin_audit_logs.created_at #{direction}"))
      when :user
        scope.joins(:user).order(Arel.sql("users.email #{direction}"))
      when :action
        scope.order(Arel.sql("admin_audit_logs.action #{direction}"))
      when :resource_type
        scope.order(Arel.sql("admin_audit_logs.resource_type #{direction}, admin_audit_logs.resource_id #{direction}"))
      else
        scope.order(created_at: :desc)
      end
    end

    def apply_auth_sorting(scope)
      column = params[:sort]&.to_sym
      direction = params[:direction] == "asc" ? "ASC" : "DESC"

      case column
      when :created_at
        scope.order(Arel.sql("authentication_logs.created_at #{direction}"))
      when :action
        scope.order(Arel.sql("authentication_logs.action #{direction}"))
      when :user
        scope.left_joins(:user).order(Arel.sql("COALESCE(users.email, authentication_logs.email_hash) #{direction}"))
      when :ip_address
        scope.order(Arel.sql("authentication_logs.ip_address #{direction}"))
      else
        scope.order(created_at: :desc)
      end
    end

    def apply_doc_event_sorting(scope)
      column = params[:sort]&.to_sym
      direction = params[:direction] == "asc" ? "ASC" : "DESC"

      case column
      when :created_at
        scope.order(Arel.sql("document_event_logs.created_at #{direction}"))
      when :event_type
        scope.order(Arel.sql("document_event_logs.event_type #{direction}"))
      when :document
        scope.joins(:document).order(Arel.sql("documents.source_file_name #{direction}"))
      when :governing_body
        scope.joins(document: :governing_body).order(Arel.sql("governing_bodies.name #{direction}"))
      else
        scope.order(created_at: :desc)
      end
    end

    # Filter counts for UI pills - consolidated into single queries
    def admin_log_filter_counts
      counts = AdminAuditLog.group(
        Arel.sql("CASE
          WHEN action LIKE 'user_%' THEN 'users'
          WHEN action LIKE 'person_%' THEN 'people'
          WHEN action LIKE 'document_%' THEN 'documents'
          ELSE 'other'
        END")
      ).count

      {
        all: counts.values.sum,
        users: counts["users"] || 0,
        people: counts["people"] || 0,
        documents: counts["documents"] || 0
      }
    end

    def auth_log_filter_counts
      counts = AuthenticationLog.group(
        Arel.sql("CASE
          WHEN action = 'login_success' OR action = 'magic_link_used' THEN 'success'
          WHEN action = 'login_failed' THEN 'failed'
          ELSE 'other'
        END")
      ).count

      {
        all: counts.values.sum,
        success: counts["success"] || 0,
        failed: counts["failed"] || 0
      }
    end

    def doc_event_filter_counts
      # Match original scope definitions:
      # - successful: event_type == "extraction_completed"
      # - failed: event_type == "extraction_failed"
      # - extraction: any extraction_* event (includes completed, failed, started)
      #
      # Uses conditional aggregation in a single query for all counts
      result = DocumentEventLog.select(
        "COUNT(*) as total",
        "COUNT(CASE WHEN event_type = 'extraction_completed' THEN 1 END) as success",
        "COUNT(CASE WHEN event_type = 'extraction_failed' THEN 1 END) as failed",
        "COUNT(CASE WHEN event_type LIKE 'extraction_%' THEN 1 END) as extraction"
      ).take

      {
        all: result.total,
        success: result.success,
        failed: result.failed,
        extraction: result.extraction
      }
    end
  end
end
