class MapCompiler
  module MapParser
    def parse_metamap
      lines = @metamap.rstrip.split("\n")
      return [] if lines.empty?
      
      element_refs = []
      
      lines.each_with_index do |line, meta_y|
        line.chars.each_with_index do |char, meta_x|
          next if char == ' ' || char == "\t"
          element_name = @metapalette[char]
          next unless element_name && @elements[element_name]
          element_refs << {
            meta_x: meta_x,
            meta_y: meta_y,
            element_name: element_name
          }
        end
      end
      
      max_meta_x = element_refs.map { |r| r[:meta_x] }.max || 0
      
      # Column widths (for X positioning) - only consider room elements
      col_widths = Array.new(max_meta_x + 1, 0)
      element_refs.each do |ref|
        element = @elements[ref[:element_name]]
        next unless element['room']
        size = @element_sizes[ref[:element_name]]
        col_widths[ref[:meta_x]] = [col_widths[ref[:meta_x]], size[:width]].max
      end
      
      col_offsets = [0]
      col_widths.each_with_index { |w, i| col_offsets << col_offsets.last + w + (i < col_widths.length - 1 ? @metamap_gap : 0) }
      
      # Track each column's current bottom position (for vertical stacking)
      col_bottoms = Array.new(max_meta_x + 1, 0)
      
      # Process elements row by row
      instance_counts = Hash.new(0)
      placements = []
      
      element_refs.group_by { |ref| ref[:meta_y] }.sort.each do |meta_y, row_elements|
        # All elements in the same row start at the same Y (max col_bottom of columns in this row)
        row_cols = row_elements.map { |ref| ref[:meta_x] }
        row_start_y = row_cols.map { |col| col_bottoms[col] }.max
        
        row_elements.each do |ref|
          element = @elements[ref[:element_name]]
          size = @element_sizes[ref[:element_name]]
          col = ref[:meta_x]
          
          instance_counts[ref[:element_name]] += 1
          placements << {
            element_name: ref[:element_name],
            instance_id: instance_counts[ref[:element_name]],
            local_x: col_offsets[col],
            local_y: row_start_y
          }
          
          # Update column bottom (only room elements affect stacking)
          col_bottoms[col] = row_start_y + size[:height] + @metamap_gap if element['room']
        end
      end
      
      # Calculate total size and center everything
      total_width = col_offsets.last
      total_height = col_bottoms.max || 0
      center_offset_x = (MAP_SIZE - total_width) / 2
      center_offset_y = (MAP_SIZE - total_height) / 2
      
      placements.each do |p|
        p[:local_x] += center_offset_x
        p[:local_y] += center_offset_y
      end
      
      placements
    end
  end
end
