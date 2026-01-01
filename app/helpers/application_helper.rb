module ApplicationHelper
  include Pagy::Frontend

  # Renders a sortable column header for tables
  # @param column [Symbol] the database column to sort by
  # @param label [String] display text
  # @param current_sort [String] current sort column from params
  # @param current_direction [String] current sort direction from params ("asc" or "desc")
  # @param path_helper [Symbol] the path helper method name (e.g., :admin_admin_logs_path)
  # @param preserved_params [Hash] current request params to preserve when sorting
  def sortable_column(column:, label:, current_sort:, current_direction:, path_helper:, preserved_params:)
    is_current = current_sort == column.to_s
    next_direction = is_current && current_direction == "asc" ? "desc" : "asc"

    icon_name = if is_current
      current_direction == "asc" ? "chevron-up" : "chevron-down"
    end

    link_params = preserved_params.merge(sort: column, direction: next_direction)

    link_to send(path_helper, link_params), class: "flex items-center gap-1 hover:text-primary" do
      concat content_tag(:span, label)
      concat icon(icon_name, size: "w-3 h-3") if icon_name
    end
  end
end
