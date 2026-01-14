class String
  def indent(n)
    self.lines.map{ |line| " " * n + line }.join
  end
end
