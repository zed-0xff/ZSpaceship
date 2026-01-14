require 'set'

# Store the original Object#inspect for fallback
class Object
  alias_method :_original_inspect, :inspect unless method_defined?(:_original_inspect)
end

module BetterInspect
  # Objects that are safe to print multiple times and should use their native inspect
  SIMPLE_TYPES = [String, Integer, Float, Symbol, TrueClass, FalseClass, NilClass, Range, Regexp]

  def binspect(visited = nil)
    # For simple types, use their native inspect method directly
    if SIMPLE_TYPES.any? { |c| is_a?(c) }
      return self.class.instance_method(:inspect).bind(self).call
    end

    ivars = instance_variables
    is_container = is_a?(Array) || is_a?(Hash) || is_a?(Set)

    # For objects with no internal state, fallback to the original Object#inspect
    if ivars.empty? && !is_container
      return _original_inspect
    end

    # Recursion protection for complex objects
    visited ||= Set.new
    return "#<#{self.class} ...>" if visited.include?(self.object_id)
    visited.add(self.object_id)

    # Custom formatting for objects with instance variables
    oid = "0x%014x" % (object_id << 1) rescue "???"
    header = "#<#{self.class}:#{oid}"
    
    parts = ivars.map do |var|
      val = instance_variable_get(var)
      "#{var}=#{val.binspect(visited)}"
    end
    
    if parts.empty?
      "#{header}>"
    else
      "#{header} #{parts.join(', ')}>"
    end
  end
end

class Object
  include BetterInspect
  def inspect
    binspect
  end
end

class Array
  def inspect
    binspect
  end

  def binspect(visited = nil)
    visited ||= Set.new
    return "[...]" if visited.include?(self.object_id)
    visited.add(self.object_id)

    if size > 10
      "[#{size}]{#{self[0, 10].map { |v| v.binspect(visited) }.join(', ')}, …}"
    else
      "[#{map { |v| v.binspect(visited) }.join(', ')}]"
    end
  end
end

class Hash
  def inspect
    binspect
  end

  def binspect(visited = nil)
    visited ||= Set.new
    return "{...}" if visited.include?(self.object_id)
    visited.add(self.object_id)

    if size > 10
      keys = self.keys[0, 10]
      "{#{size}}{#{keys.map { |k| "#{k.binspect(visited)}=>#{self[k].binspect(visited)}" }.join(', ')}, …}"
    else
      "{#{map { |k, v| "#{k.binspect(visited)}=>#{v.binspect(visited)}" }.join(', ')}}"
    end
  end
end

class Set
  def inspect
    binspect
  end

  def binspect(visited = nil)
    visited ||= Set.new
    return "Set<...>" if visited.include?(self.object_id)
    visited.add(self.object_id)

    if size > 10
      "Set<#{size}>{#{to_a[0, 10].map { |v| v.binspect(visited) }.join(', ')}, …}"
    else
      "Set<#{map { |v| v.binspect(visited) }.join(', ')}>"
    end
  end
end
