class DocumentsController < ApplicationController
  def index
    @status_counts = Document.group(:status).count
    @documents = Document.order(created_at: :desc).limit(100)
  end

  def show
    @document = Document.find(params[:id])
  end
end
