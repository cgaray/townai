# frozen_string_literal: true

class TopicsController < ApplicationController
  include TownScoped

  def index
    topics = base_scope
    topics = apply_filters(topics)

    @filter_counts = Topic.filter_counts_for_town(current_town)
    @pagy, @topics = pagy(topics, limit: 50)
  end

  private

  def base_scope
    Topic
      .for_town(current_town)
      .includes(document: :governing_body)
      .joins(:document)
      .merge(Document.complete)
      .order("documents.created_at DESC, topics.position ASC")
  end

  def apply_filters(scope)
    scope = filter_by_action(scope)
    scope = filter_by_governing_body(scope)
    scope
  end

  def filter_by_action(scope)
    return scope if params[:action_taken].blank?

    if params[:action_taken] == "with_actions"
      scope.with_actions
    elsif Topic.action_takens.key?(params[:action_taken])
      scope.where(action_taken: params[:action_taken])
    else
      scope
    end
  end

  def filter_by_governing_body(scope)
    return scope if params[:governing_body_id].blank?

    scope.joins(:governing_body).where(governing_bodies: { id: params[:governing_body_id] })
  end
end
