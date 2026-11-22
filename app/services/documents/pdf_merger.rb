require "combine_pdf"

module Documents
  class PdfMerger
    def self.join(paths)
      merged = CombinePDF.new
      Array(paths).each do |path|
        next if path.blank? || !File.file?(path) || File.empty?(path)

        merged << CombinePDF.load(path.to_s)
      end
      merged.to_pdf
    end
  end
end
