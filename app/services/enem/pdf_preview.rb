module Enem
  module PdfPreview
    module_function

    def jpeg(pdf_path)
      dir = Dir.mktmpdir("maestro-enem-card")
      prefix = File.join(dir, "page")

      if executable?("pdftoppm")
        system(
          "pdftoppm", "-jpeg", "-singlefile", "-f", "1", "-l", "1", "-r", "140",
          pdf_path.to_s, prefix,
          exception: false
        )
        path = "#{prefix}.jpg"
        return path if File.file?(path)
      end

      if executable?("magick")
        path = "#{prefix}.jpg"
        system("magick", "-density", "140", "#{pdf_path}[0]", "-quality", "85", path, exception: false)
        return path if File.file?(path)
      end

      FileUtils.remove_entry(dir)
      nil
    end

    def executable?(name)
      extensions = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
        extensions.any? { |ext| File.executable?(File.join(dir, "#{name}#{ext}")) }
      end
    end
  end
end
