# Backport changes to YAML in MRI r16082 (v1.8.7)
# that fixes quick_emit and built-in support for Ruby types
# so that we prevent repeated object references when emitting YAML
#
# Experiments: http://gist.github.com/93313
# Bug report: http://rubyforge.org/tracker/?func=detail&atid=1698&aid=8548&group_id=426
# SVN: http://redmine.ruby-lang.org/repositories/diff/ruby-18?rev=16082

YAML.module_eval do
  def quick_emit(oid, opts = {}, &e)
    out = 
      if opts.is_a? YAML::Emitter
        opts
      else
        emitter.reset( opts )
      end
    oid = "#{oid.object_id}-#{oid.hash}" unless Fixnum === oid or NilClass === oid
    out.emit( oid, &e )
  end
end

YAML::Object.class_eval do
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      out.map("tag:ruby.yaml.org,2002:object:#{ @class }", to_yaml_style) do |map|
        @ivars.each do |k,v|
          map.add(k, v)
        end
      end
    end
  end
end

YAML::Omap.class_eval do
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      out.seq(taguri, to_yaml_style) do |seq|
        self.each do |v|
          seq.add Hash[*v]
        end
      end
    end
  end
end

YAML::Pairs.class_eval do
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      out.seq(taguri, to_yaml_style) do |seq|
        self.each do |v|
          seq.add Hash[*v]
        end
      end
    end
  end
end

Object.class_eval do
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        to_yaml_properties.each do |m|
          map.add(m[1..-1], instance_variable_get(m))
        end
      end
    end
  end
end

Hash.class_eval do
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      out.map( taguri, to_yaml_style ) do |map|
        each {|k, v| map.add(k, v) }
      end
    end
  end
end

Struct.class_eval do
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      # Basic struct is passed as a YAML map
      out.map(taguri, to_yaml_style) do |map|
        self.members.each do |m|
          map.add(m, self[m])
        end
        self.to_yaml_properties.each do |m|
          map.add(m, instance_variable_get(m))
        end
      end
    end
  end
end

Array.class_eval do
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      out.seq( taguri, to_yaml_style ) do |seq|
        each {|x| seq.add(x) }
      end
    end
  end
end

Exception.class_eval do
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        map.add('message', message)
        to_yaml_properties.each do |m|
          map.add(m[1..-1], instance_variable_get(m))
        end
      end
    end
  end
end

String.class_eval do
  def to_yaml(opts = {})
    YAML::quick_emit(is_complex_yaml? ? self : nil, opts) do |out|
      if is_binary_data?
        out.scalar("tag:yaml.org,2002:binary", [self].pack("m"), :literal)
      elsif to_yaml_properties.empty?
        out.scalar(taguri, self, self =~ /^:/ ? :quote2 : to_yaml_style)
      else
        out.map(taguri, to_yaml_style) do |map|
          map.add('str', "#{self}")
          to_yaml_properties.each do |m|
            map.add(m, instance_variable_get(m))
          end
        end
      end
    end
  end
end

Range.class_eval do
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        map.add('begin', self.begin)
        map.add('end', self.end)
        map.add('excl', self.exclude_end?)
        to_yaml_properties.each do |m|
          map.add(m, instance_variable_get(m))
        end
      end
    end
  end
end

Time.class_eval do
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      tz = "Z"
      # from the tidy Tobias Peters <t-peters@gmx.de> Thanks!
      unless self.utc?
        utc_same_instant = self.dup.utc
        utc_same_writing = Time.utc(year,month,day,hour,min,sec,usec)
        difference_to_utc = utc_same_writing - utc_same_instant
        if (difference_to_utc < 0)
          difference_sign = '-'
          absolute_difference = -difference_to_utc
        else
          difference_sign = '+'
          absolute_difference = difference_to_utc
        end
        difference_minutes = (absolute_difference/60).round
        tz = "%s%02d:%02d" % [ difference_sign, difference_minutes / 60, difference_minutes % 60]
      end
      standard = self.strftime("%Y-%m-%d %H:%M:%S")
      standard += ".%06d" % [usec] if usec.nonzero?
      standard += " %s" % [tz]
      if to_yaml_properties.empty?
        out.scalar(taguri, standard, :plain)
      else
        out.map(taguri, to_yaml_style) do |map|
          map.add('at', standard)
          to_yaml_properties.each do |m|
            map.add(m, instance_variable_get(m))
          end
        end
      end
    end
  end
end

Date.class_eval do
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      out.scalar("tag:yaml.org,2002:timestamp", self.to_s, :plain)
    end
  end
end