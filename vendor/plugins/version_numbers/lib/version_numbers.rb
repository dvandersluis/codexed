class Version
  include Comparable

  attr_reader :major, :feature_group, :feature, :bugfix

  def initialize(version = "")
    v = version.to_s.split(".")
    @major = v[0].to_i
    @feature_group = v[1].to_i
    @feature = v[2].to_i
    @bugfix = v[3].to_i
  end
  
  def <=>(other)
    other = Version.new(other) unless other.is_a? Version
    return @major <=> other.major if ((@major <=> other.major) != 0)
    return @feature_group <=> other.feature_group if ((@feature_group <=> other.feature_group) != 0)
    return @feature <=> other.feature if ((@feature <=> other.feature) != 0)
    return @bugfix <=> other.bugfix
  end

  def self.sort
    self.sort!{|a,b| a <=> b}
  end

  def to_s
    @major.to_s + "." + @feature_group.to_s + "." + @feature.to_s + "." + @bugfix.to_s
  end
end

class String
  def to_version
    Version.new(self)
  end
end
