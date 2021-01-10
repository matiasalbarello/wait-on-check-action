class Check
  attr_accessor :name, :status, :conclusion

  def initialize(name, status, conclusion)
    @name = name
    @status = status
    @conclusion = conclusion
  end

  def success?
    conclusion == 'success'
  end

  def conclusion_message
    "#{name}: #{status} (#{conclusion})"
  end

  def method_missing(m, *args, &block)
    method_name = m.to_s
    if method_name[-1] == "?"
      return status == method_name[0..-2]
    else
      super
    end
  end
end