module Documents
  class PdfMerger
    def self.join(paths)
      new(paths).join
    end

    def initialize(paths)
      @paths = Array(paths).map(&:to_s).select { |path| File.file?(path) && !File.empty?(path) }
    end

    def join
      pages_id = count_kept_objects + 1
      catalog_id = pages_id + 1
      output = "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n".b
      offsets = Array.new(catalog_id + 1)
      page_ids = []
      next_id = 1

      @paths.each do |path|
        document = ParsedPdf.new(File.binread(path))
        map = {}
        document.kept_ids.each do |old_id|
          map[old_id] = next_id
          next_id += 1
        end
        document.page_ids.each { |old_id| page_ids << map[old_id] }

        document.kept_ids.each do |old_id|
          object = document.objects[old_id]
          dictionary = rewrite_references(object[:dict], map)
          if document.page_ids.include?(old_id)
            dictionary = dictionary.sub(%r{/Parent\s+\d+\s+\d+\s+R}, "/Parent #{pages_id} 0 R")
          end
          offsets[map[old_id]] = output.bytesize
          output << object_bytes(map[old_id], dictionary, object[:stream])
        end
        document.clear
      end

      offsets[pages_id] = output.bytesize
      kids = page_ids.map { |id| "#{id} 0 R" }.join(" ")
      output << object_bytes(pages_id, "<< /Type /Pages /Count #{page_ids.size} /Kids [#{kids}] >>", nil)
      offsets[catalog_id] = output.bytesize
      output << object_bytes(catalog_id, "<< /Type /Catalog /Pages #{pages_id} 0 R >>", nil)
      write_xref(output, offsets, catalog_id)
      output
    end

    private

    def count_kept_objects
      @paths.sum do |path|
        document = ParsedPdf.new(File.binread(path))
        count = document.kept_ids.size
        document.clear
        count
      end
    end

    def object_bytes(id, dictionary, stream)
      body = "#{id} 0 obj\n".b
      body << dictionary.to_s.b
      body << "\n".b
      if stream
        body << "stream\n".b
        body << stream.b
        body << "\nendstream\n".b
      end
      body << "endobj\n".b
      body
    end

    def rewrite_references(dictionary, map)
      dictionary.gsub(/(\d+)\s+(\d+)\s+R/) do
        new_id = map[Regexp.last_match(1).to_i]
        (new_id ? "#{new_id} 0 R" : Regexp.last_match(0)).b
      end
    end

    def write_xref(output, offsets, catalog_id)
      startxref = output.bytesize
      size = offsets.length
      output << "xref\n0 #{size}\n".b
      output << "0000000000 65535 f \n".b
      (1...size).each do |id|
        output << format("%010d 00000 n \n", offsets[id].to_i).b
      end
      output << "trailer\n<< /Size #{size} /Root #{catalog_id} 0 R >>\nstartxref\n#{startxref}\n%%EOF\n".b
    end

    class ParsedPdf
      attr_reader :objects, :page_ids, :kept_ids

      def initialize(data)
        @data = data.b
        @objects = {}
        parse
      end

      def clear
        @data = nil
        @objects = {}
      end

      private

      def parse
        entries = xref_entries
        entries.each do |id, entry|
          next if id.zero? || entry[:kind] != "n"

          @objects[id] = read_object(entry[:offset], entries)
        end

        trailer = trailer_dictionary
        root_id = trailer[/\/Root\s+(\d+)\s+\d+\s+R/, 1].to_i
        info_id = trailer[/\/Info\s+(\d+)\s+\d+\s+R/, 1].to_i
        pages_root = @objects.fetch(root_id)[:dict][/\/Pages\s+(\d+)\s+\d+\s+R/, 1].to_i
        tree_ids = []
        @page_ids = collect_pages(pages_root, tree_ids)
        dropped = [ root_id, info_id, *tree_ids ]
        @kept_ids = @objects.keys.reject { |id| dropped.include?(id) }.sort
      end

      def collect_pages(id, tree_ids)
        dictionary = @objects.fetch(id)[:dict]
        tree_ids << id
        kids = dictionary.scan(/\/Kids\s*\[(.*?)\]/m).flat_map do |group|
          group.first.scan(/(\d+)\s+\d+\s+R/).flatten.map(&:to_i)
        end
        kids.flat_map do |child|
          if @objects.fetch(child)[:dict].match?(%r{/Type\s*/Pages\b})
            collect_pages(child, tree_ids)
          else
            [ child ]
          end
        end
      end

      def xref_entries
        start = @data.rindex("startxref")
        raise "PDF sem startxref" unless start

        position = @data.byteslice(start, 80)[/startxref\s+(\d+)/, 1].to_i
        lines = @data.byteslice(position, @data.bytesize - position).split(/\r?\n/)
        entries = {}
        index = 1
        while index < lines.length && !lines[index].to_s.start_with?("trailer")
          header = lines[index].match(/\A(\d+)\s+(\d+)\z/)
          unless header
            index += 1
            next
          end

          first = header[1].to_i
          count = header[2].to_i
          count.times do |step|
            row = lines[index + 1 + step].to_s
            entries[first + step] = { offset: row[0, 10].to_i, kind: row[17].to_s }
          end
          index += count + 1
        end
        entries
      end

      def trailer_dictionary
        start = @data.rindex("trailer")
        finish = @data.rindex("startxref")
        @data.byteslice(start, finish - start)
      end

      def read_object(offset, entries)
        match = @data.match(/\d+\s+\d+\s+obj\s*/m, offset)
        raise "objeto PDF inválido em #{offset}" unless match

        body_start = match.end(0)
        stream_at = @data.match(/>>\s*stream\r?\n/m, body_start)
        endobj_at = @data.index("endobj", body_start)
        if stream_at && endobj_at && stream_at.begin(0) < endobj_at
          dictionary = @data.byteslice(body_start, stream_at.begin(0) - body_start + 2)
          length = stream_length(dictionary, entries)
          stream = @data.byteslice(stream_at.end(0), length)
          { dict: dictionary.strip, stream: stream }
        else
          dictionary = @data.byteslice(body_start, endobj_at - body_start)
          { dict: dictionary.strip, stream: nil }
        end
      end

      def stream_length(dictionary, entries)
        reference = dictionary.match(/\/Length\s+(\d+)\s+\d+\s+R/)
        if reference
          length_object = read_object(entries.fetch(reference[1].to_i)[:offset], entries)
          length_object[:dict][/\d+/].to_i
        else
          dictionary[/\/Length\s+(\d+)/, 1].to_i
        end
      end
    end
  end
end
