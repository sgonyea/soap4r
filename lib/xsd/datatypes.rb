=begin
XSD4R - XML Schema Datatype implementation.
Copyright (C) 2000, 2001, 2002, 2003  NAKAMURA, Hiroshi.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PRATICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 675 Mass
Ave, Cambridge, MA 02139, USA.
=end


require 'xsd/qname'
require 'xsd/charset'
require 'uri'


###
## XMLSchamaDatatypes general definitions.
#
module XSD


Namespace = 'http://www.w3.org/2001/XMLSchema'
InstanceNamespace = 'http://www.w3.org/2001/XMLSchema-instance'

AttrType = 'type'
NilValue = 'true'

AnyTypeLiteral = 'anyType'
AnySimpleTypeLiteral = 'anySimpleType'
NilLiteral = 'nil'
StringLiteral = 'string'
BooleanLiteral = 'boolean'
DecimalLiteral = 'decimal'
FloatLiteral = 'float'
DoubleLiteral = 'double'
DurationLiteral = 'duration'
DateTimeLiteral = 'dateTime'
TimeLiteral = 'time'
DateLiteral = 'date'
GYearMonthLiteral = 'gYearMonth'
GYearLiteral = 'gYear'
GMonthDayLiteral = 'gMonthDay'
GDayLiteral = 'gDay'
GMonthLiteral = 'gMonth'
HexBinaryLiteral = 'hexBinary'
Base64BinaryLiteral = 'base64Binary'
AnyURILiteral = 'anyURI'
QNameLiteral = 'QName'

NormalizedStringLiteral = 'normalizedString'
IntegerLiteral = 'integer'
LongLiteral = 'long'
IntLiteral = 'int'
ShortLiteral = 'short'

AttrTypeName = QName.new(InstanceNamespace, AttrType)
AttrNilName = QName.new(InstanceNamespace, NilLiteral)

AnyTypeName = QName.new(Namespace, AnyTypeLiteral)
AnySimpleTypeName = QName.new(Namespace, AnySimpleTypeLiteral)

class Error < StandardError; end
class ValueSpaceError < Error; end


###
## The base class of all datatypes with Namespace.
#
class NSDBase
  @@types = []

  attr_accessor :type

  def self.inherited(klass)
    @@types << klass
  end

  def self.types
    @@types
  end

  def initialize
    @type = nil
  end
end


###
## The base class of XSD datatypes.
#
class XSDAnySimpleType < NSDBase
  include XSD
  Type = QName.new(Namespace, AnySimpleTypeLiteral)

  # @data represents canonical space (ex. Integer: 123).
  attr_reader :data
  # @is_nil represents this data is nil or not.
  attr_accessor :is_nil

  def initialize(value = nil)
    super()
    @type = Type
    @data = nil
    @is_nil = true
    set(value) if value
  end

  # set accepts a string which follows lexical space (ex. String: "+123"), or
  # an object which follows canonical space (ex. Integer: 123).
  def set(value)
    if value.nil?
      @is_nil = true
      @data = nil
    else
      @is_nil = false
      _set(value)
    end
  end

  # to_s creates a string which follows lexical space (ex. String: "123").
  def to_s()
    if @is_nil
      ""
    else
      _to_s
    end
  end

  def trim(data)
    data.sub(/\A\s*(\S*)\s*\z/, '\1')
  end

private

  def _set(value)
    @data = value
  end

  def _to_s
    @data.to_s
  end
end

class XSDNil < XSDAnySimpleType
  Type = QName.new(Namespace, NilLiteral)
  Value = 'true'

  def initialize(value = nil)
    super()
    @type = Type
    set(value)
  end

private

  def _set(value)
    @data = value
  end
end


###
## Primitive datatypes.
#
class XSDString < XSDAnySimpleType
  Type = QName.new(Namespace, StringLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    @encoding = nil
    set(value) if value
  end

private

  def _set(value)
    unless XSD::Charset.is_ces(value, XSD::Charset.encoding)
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end
    @data = value
  end
end

class XSDBoolean < XSDAnySimpleType
  Type = QName.new(Namespace, BooleanLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value)
  end

private

  def _set(value)
    if value.is_a?(String)
      str = trim(value)
      if str == 'true' || str == '1'
	@data = true
      elsif str == 'false' || str == '0'
	@data = false
      else
	raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
      end
    else
      @data = value ? true : false
    end
  end
end

class XSDDecimal < XSDAnySimpleType
  Type = QName.new(Namespace, DecimalLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    @sign = ''
    @number = ''
    @point = 0
    set(value) if value
  end

  def nonzero?
    (@number != '0')
  end

private

  def _set(d)
    if d.is_a?(String)
      # Integer("00012") => 10 in Ruby.
      d.sub!(/^([+\-]?)0*(?=\d)/, "\\1")
    end
    set_str(d)
  end

  def set_str(str)
    /^([+\-]?)(\d*)(?:\.(\d*)?)?$/ =~ trim(str.to_s)
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end

    @sign = $1 || '+'
    int_part = $2
    frac_part = $3

    int_part = '0' if int_part.empty?
    frac_part = frac_part ? frac_part.sub(/0+$/, '') : ''
    @point = - frac_part.size
    @number = int_part + frac_part

    # normalize
    if @sign == '+'
      @sign = ''
    elsif @sign == '-'
      if @number == '0'
	@sign = ''
      end
    end

    @data = _to_s
  end

  # 0.0 -> 0; right?
  def _to_s
    str = @number.dup
    if @point.nonzero?
      str[@number.size + @point, 0] = '.'
    end
    @sign + str
  end
end

class XSDFloat < XSDAnySimpleType
  Type = QName.new(Namespace, FloatLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def _set(value)
    # "NaN".to_f => 0 in some environment.  libc?
    if value.is_a?(Float)
      @data = narrow32bit(value)
      return
    end

    str = trim(value.to_s)
    if str == 'NaN'
      @data = 0.0/0.0
    elsif str == 'INF'
      @data = 1.0/0.0
    elsif str == '-INF'
      @data = -1.0/0.0
    else
      if /^[+\-\.\deE]+$/ !~ str
	raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
      end
      # Float("-1.4E") might fail on some system.
      str << '0' if /e$/i =~ str
      begin
  	@data = narrow32bit(Float(str))
      rescue ArgumentError
  	raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
      end
    end
  end

  # Do I have to convert 0.0 -> 0 and -0.0 -> -0 ?
  def _to_s
    if @data.nan?
      'NaN'
    elsif @data.infinite? == 1
      'INF'
    elsif @data.infinite? == -1
      '-INF'
    else
      sprintf("%.10g", @data)
    end
  end

  # Convert to single-precision 32-bit floating point value.
  def narrow32bit(f)
    if f.nan? || f.infinite?
      f
    else
      packed = [f].pack("f")
      (/\A\0*\z/ =~ packed)? 0.0 : f
    end
  end
end

# Ruby's Float is double-precision 64-bit floating point value.
class XSDDouble < XSDAnySimpleType
  Type = QName.new(Namespace, DoubleLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def _set(value)
    # "NaN".to_f => 0 in some environment.  libc?
    if value.is_a?(Float)
      @data = value
      return
    end

    str = trim(value.to_s)
    if str == 'NaN'
      @data = 0.0/0.0
    elsif str == 'INF'
      @data = 1.0/0.0
    elsif str == '-INF'
      @data = -1.0/0.0
    else
      begin
	@data = Float(str)
      rescue ArgumentError
	# '1.4e' cannot be parsed on some architecture.
	if /e\z/i =~ str
	  begin
	    @data = Float(str + '0')
	  rescue ArgumentError
	    raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
	  end
	else
	  raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
	end
      end
    end
  end

  # Do I have to convert 0.0 -> 0 and -0.0 -> -0 ?
  def _to_s
    if @data.nan?
      'NaN'
    elsif @data.infinite? == 1
      'INF'
    elsif @data.infinite? == -1
      '-INF'
    else
      sprintf("%.16g", @data)
    end
  end
end

class XSDDuration < XSDAnySimpleType
  Type = QName.new(Namespace, DurationLiteral)

  attr_accessor :sign
  attr_accessor :year
  attr_accessor :month
  attr_accessor :day
  attr_accessor :hour
  attr_accessor :min
  attr_accessor :sec

  def initialize(value = nil)
    super()
    @type = Type
    @sign = nil
    @year = nil
    @month = nil
    @day = nil
    @hour = nil
    @min = nil
    @sec = nil
    set(value) if value
  end

private

  def _set(value)
    /^([+\-]?)P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$/ =~ trim(value.to_s)
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end

    if ($5 and ((!$2 and !$3 and !$4) or (!$6 and !$7 and !$8)))
      # Should we allow 'PT5S' here?
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end

    @sign = $1
    @year = $2.to_i
    @month = $3.to_i
    @day = $4.to_i
    @hour = $6.to_i
    @min = $7.to_i
    @sec = $8 ? XSDDecimal.new($8) : 0
    @data = _to_s
  end

  def _to_s
    str = ''
    str << @sign if @sign
    str << 'P'
    l = ''
    l << "#{ @year }Y" if @year.nonzero?
    l << "#{ @month }M" if @month.nonzero?
    l << "#{ @day }D" if @day.nonzero?
    r = ''
    r << "#{ @hour }H" if @hour.nonzero?
    r << "#{ @min }M" if @min.nonzero?
    r << "#{ @sec }S" if @sec.nonzero?
    str << l
    if l.empty?
      str << "0D"
    end
    unless r.empty?
      str << "T" << r
    end
    str
  end
end


require 'rational'
require 'date'
unless Object.const_defined?('DateTime')
  raise LoadError.new('XSD4R requires date2/3.2 or later to be installed.  You can download it from http://www.funaba.org/en/ruby.html#date2')
end

module XSDDateTimeImpl
  SecInDay = 86400	# 24 * 60 * 60

  def to_time
    begin
      if @data.of * SecInDay == Time.now.utc_offset
        d = @data
        usec = (d.sec_fraction * SecInDay * 1000000).to_f
        Time.local(d.year, d.month, d.mday, d.hour, d.min, d.sec, usec)
      else
        d = @data.newof
        usec = (d.sec_fraction * SecInDay * 1000000).to_f
        Time.gm(d.year, d.month, d.mday, d.hour, d.min, d.sec, usec)
      end
    rescue ArgumentError
      nil
    end
  end

  def tz2of(str)
    /^(?:Z|(?:([+\-])(\d\d):(\d\d))?)$/ =~ str
    sign = $1
    hour = $2.to_i
    min = $3.to_i

    of = case sign
      when '+'
	of = +(hour.to_r * 60 + min) / 1440	# 24 * 60
      when '-'
	of = -(hour.to_r * 60 + min) / 1440	# 24 * 60
      else
	0
      end
    of
  end

  def of2tz(offset)
    diffmin = offset * 24 * 60
    if diffmin.zero?
      'Z'
    else
      ((diffmin < 0) ? '-' : '+') << format('%02d:%02d',
    	(diffmin.abs / 60.0).to_i, (diffmin.abs % 60.0).to_i)
    end
  end

  def _set(t)
    if (t.is_a?(Date))
      @data = t
    elsif (t.is_a?(Time))
      sec, min, hour, mday, month, year = t.to_a[0..5]
      diffday = t.usec.to_r / 1000000 / SecInDay
      of = t.utc_offset.to_r / SecInDay
      @data = DateTime.civil(year, month, mday, hour, min, sec, of)
      @data += diffday
    else
      set_str(t)
    end
  end

  def add_tz(s)
    s + of2tz(@data.offset)
  end
end

class XSDDateTime < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, DateTimeLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(t)
    /^([+\-]?\d\d\d\d\d*)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d(?:\.(\d*))?)(Z|(?:[+\-]\d\d:\d\d)?)?$/ =~ trim(t.to_s)
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end
    if $1 == '0000'
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    year = $1.to_i
    if year < 0
      year += 1
    end
    mon = $2.to_i
    mday = $3.to_i
    hour = $4.to_i
    min = $5.to_i
    sec = $6.to_i
    secfrac = $7
    zonestr = $8

    @data = DateTime.civil(year, mon, mday, hour, min, sec, tz2of(zonestr))

    if secfrac
      diffday = secfrac.to_i.to_r / (10 ** secfrac.size) / SecInDay
      # jd = @data.jd
      # day_fraction = @data.day_fraction + diffday
      # @data = DateTime.new0(DateTime.jd_to_rjd(jd, day_fraction,
      #   @data.offset), @data.offset)
      #
      # Thanks to Funaba-san, above code can be simply written as below.
      @data += diffday
      # FYI: new0 and jd_to_rjd are not necessary to use if you don't have
      # exceptional reason.
    end
  end

  def _to_s
    year = (@data.year > 0) ? @data.year : @data.year - 1
    s = format('%.4d-%02d-%02dT%02d:%02d:%02d',
      year, @data.mon, @data.mday, @data.hour, @data.min, @data.sec)
    if @data.sec_fraction.nonzero?
      fr = @data.sec_fraction * SecInDay
      shiftsize = fr.denominator.to_s.size
      fr_s = (fr * (10 ** shiftsize)).to_i.to_s
      s << '.' << '0' * (shiftsize - fr_s.size) << fr_s.sub(/0+$/, '')
    end
    add_tz(s)
  end
end

class XSDTime < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, TimeLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(t)
    /^(\d\d):(\d\d):(\d\d(?:\.(\d*))?)(Z|(?:([+\-])(\d\d):(\d\d))?)?$/ =~ trim(t.to_s)
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    hour = $1.to_i
    min = $2.to_i
    sec = $3.to_i
    secfrac = $4
    zonestr = $5

    @data = DateTime.civil(1, 1, 1, hour, min, sec, tz2of(zonestr))

    if secfrac
      @data += secfrac.to_i.to_r / (10 ** secfrac.size) / SecInDay
    end
  end

  def _to_s
    s = format('%02d:%02d:%02d', @data.hour, @data.min, @data.sec)
    if @data.sec_fraction.nonzero?
      fr = @data.sec_fraction * SecInDay
      shiftsize = fr.denominator.to_s.size
      fr_s = (fr * (10 ** shiftsize)).to_i.to_s
      s << '.' << '0' * (shiftsize - fr_s.size) << fr_s.sub(/0+$/, '')
    end
    add_tz(s)
  end
end

class XSDDate < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, DateLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(t)
    /^([+\-]?\d\d\d\d\d*)-(\d\d)-(\d\d)(Z|(?:([+\-])(\d\d):(\d\d))?)?$/ =~ trim(t.to_s)
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    year = $1.to_i
    if year < 0
      year += 1
    end
    mon = $2.to_i
    mday = $3.to_i
    zonestr = $4

    @data = DateTime.civil(year, mon, mday, 0, 0, 0, tz2of(zonestr))
  end

  def _to_s
    year = (@data.year > 0) ? @data.year : @data.year - 1
    s = format('%.4d-%02d-%02d', year, @data.mon, @data.mday)
    add_tz(s)
  end
end

class XSDGYearMonth < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, GYearMonthLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(t)
    /^([+\-]?\d\d\d\d\d*)-(\d\d)(Z|(?:([+\-])(\d\d):(\d\d))?)?$/ =~ trim(t.to_s)
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    year = $1.to_i
    if year < 0
      year += 1
    end
    mon = $2.to_i
    zonestr = $3

    @data = DateTime.civil(year, mon, 1, 0, 0, 0, tz2of(zonestr))
  end

  def _to_s
    year = (@data.year > 0) ? @data.year : @data.year - 1
    s = format('%.4d-%02d', year, @data.mon)
    add_tz(s)
  end
end

class XSDGYear < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, GYearLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(t)
    /^([+\-]?\d\d\d\d\d*)(Z|(?:([+\-])(\d\d):(\d\d))?)?$/ =~ trim(t.to_s)
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    year = $1.to_i
    if year < 0
      year += 1
    end
    zonestr = $2

    @data = DateTime.civil(year, 1, 1, 0, 0, 0, tz2of(zonestr))
  end

  def _to_s
    year = (@data.year > 0) ? @data.year : @data.year - 1
    s = format('%.4d', year)
    add_tz(s)
  end
end

class XSDGMonthDay < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, GMonthDayLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(t)
    /^(\d\d)-(\d\d)(Z|(?:[+\-]\d\d:\d\d)?)?$/ =~ trim(t.to_s)
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    mon = $1.to_i
    mday = $2.to_i
    zonestr = $3

    @data = DateTime.civil(1, mon, mday, 0, 0, 0, tz2of(zonestr))
  end

  def _to_s
    s = format('%02d-%02d', @data.mon, @data.mday)
    add_tz(s)
  end
end

class XSDGDay < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, GDayLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(t)
    /^(\d\d)(Z|(?:[+\-]\d\d:\d\d)?)?$/ =~ trim(t.to_s)
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    mday = $1.to_i
    zonestr = $2

    @data = DateTime.civil(1, 1, mday, 0, 0, 0, tz2of(zonestr))
  end

  def _to_s
    s = format('%02d', @data.mday)
    add_tz(s)
  end
end

class XSDGMonth < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, GMonthLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(t)
    /^(\d\d)(Z|(?:[+\-]\d\d:\d\d)?)?$/ =~ trim(t.to_s)
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    mon = $1.to_i
    zonestr = $2

    @data = DateTime.civil(1, mon, 1, 0, 0, 0, tz2of(zonestr))
  end

  def _to_s
    s = format('%02d', @data.mon)
    add_tz(s)
  end
end

class XSDHexBinary < XSDAnySimpleType
  Type = QName.new(Namespace, HexBinaryLiteral)

  # String in Ruby could be a binary.
  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

  def set_encoded(value)
    if /^[0-9a-fA-F]*$/ !~ value
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end
    @data = trim(String.new(value))
    @is_nil = false
  end

  def string
    [@data].pack("H*")
  end

private

  def _set(value)
    @data = value.unpack("H*")[0]
    @data.tr!('a-f', 'A-F')
  end
end

class XSDBase64Binary < XSDAnySimpleType
  Type = QName.new(Namespace, Base64BinaryLiteral)

  # String in Ruby could be a binary.
  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

  def set_encoded(value)
    if /^[A-Za-z0-9+\/=]*$/ !~ value
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end
    @data = trim(String.new(value))
    @is_nil = false
  end

  def string
    @data.unpack("m")[0]
  end

private

  def _set(value)
    @data = trim([value].pack("m"))
  end
end

class XSDAnyURI < XSDAnySimpleType
  Type = QName.new(Namespace, AnyURILiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def _set(value)
    begin
      @data = URI.parse(trim(value.to_s))
    rescue URI::InvalidURIError
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end
  end
end

class XSDQName < XSDAnySimpleType
  Type = QName.new(Namespace, QNameLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def _set(value)
    /^(?:([^:]+):)?([^:]+)$/ =~ trim(value.to_s)
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end

    @prefix = $1
    @localpart = $2
    @data = _to_s
  end

  def _to_s
    if @prefix
      "#{ @prefix }:#{ @localpart }"
    else
      "#{ @localpart }"
    end
  end
end


###
## Derived types
#
class XSDNormalizedString < XSDString
  Type = QName.new(Namespace, NormalizedStringLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def _set(value)
    if /[\t\r\n]/ =~ value
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end
    super
  end
end

class XSDInteger < XSDDecimal
  Type = QName.new(Namespace, IntegerLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(str)
    begin
      @data = Integer(str)
    rescue ArgumentError
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
  end

  def _to_s()
    @data.to_s
  end
end

class XSDLong < XSDInteger
  Type = QName.new(Namespace, LongLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(str)
    begin
      @data = Integer(str)
    rescue ArgumentError
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
    unless validate(@data)
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
  end

  MaxInclusive = +9223372036854775807
  MinInclusive = -9223372036854775808
  def validate(v)
    ((MinInclusive <= v) && (v <= MaxInclusive))
  end
end

class XSDInt < XSDLong
  Type = QName.new(Namespace, IntLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(str)
    begin
      @data = Integer(str)
    rescue ArgumentError
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
    unless validate(@data)
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
  end

  MaxInclusive = +2147483647
  MinInclusive = -2147483648
  def validate(v)
    ((MinInclusive <= v) && (v <= MaxInclusive))
  end
end

class XSDShort < XSDInt
  Type = QName.new(Namespace, ShortLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(str)
    begin
      @data = Integer(str)
    rescue ArgumentError
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
    unless validate(@data)
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
  end

  MaxInclusive = +32767
  MinInclusive = -32768
  def validate(v)
    ((MinInclusive <= v) && (v <= MaxInclusive))
  end
end


end


include XSD	# Include XSD's constants to toplevel.