class ExtractTextJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find(document_id)
    return unless document.pending?
    return unless document.pdf.attached?

    document.update!(status: :extracting_text)

    document.pdf.open do |file|
      text = extract_with_poppler(file.path)
      text = extract_with_tesseract(file.path) if text.strip.empty?
      document.update!(raw_text: text, status: :extracting_metadata)
    end
  rescue => e
    document.update!(status: :failed)
    raise e
  end

  private

  def extract_with_poppler(path)
    `pdftotext -layout "#{path}" -`.strip
  end

  def extract_with_tesseract(path)
    Dir.mktmpdir do |dir|
      `pdftoppm -png "#{path}" "#{dir}/page"`
      Dir.glob("#{dir}/page-*.png").sort.map do |img|
        `tesseract "#{img}" stdout 2>/dev/null`
      end.join("\n")
    end
  end
end
