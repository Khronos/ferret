require 'date'
module Ferret::Utils
  # Provides support for converting dates to strings and vice-versa.  The
  # strings are structured so that lexicographic sorting orders them by
  # date, which makes them suitable for use as field values and search
  # terms.
  # 
  # This class also helps you to limit the resolution of your dates. Do not
  # save dates with a finer resolution than you really need, as then
  # RangeQuery and PrefixQuery will require more memory and become slower.
  # 
  # Compared to the serialize methods the strings generated by the to_s
  # methods in this class take slightly more space, unless your selected
  # resolution is set to _Resolution.DAY_ or lower.

  # Provides support for converting dates to strings and vice-versa.  The
  # strings are structured so that lexicographic sorting orders by date,
  # which makes them suitable for use as field values and search terms.
  # 
  # Note:: dates before 1970 cannot be used, and therefore cannot be indexed
  # when using this class.
  module DateTools
    # make date strings long enough to last a millenium
    SERIALIZED_DATE_LEN = (1000*365*24*60*60*1000).to_s(36).length

    # The latest date that can be stored in this format
    MAX_SERIALIZED_DATE_STRING = Array.new(SERIALIZED_DATE_LEN, "z").to_s.to_i(36)

    # Converts a Date to a string suitable for indexing.  Throws Exception
    # if the date specified in the method argument is before 1970 This
    # method is unsupported. Please use Time instead of Date
    def DateTools.serialize_date(date)
      return serialize_time(Time.parse(date))
    end

    # Converts a millisecond time to a string suitable for indexing.
    # Accepts a Time object or a time in milliseconds.
    #
    # Throws Exception if the time specified in the method argument is
    # negative, that is, before 1970 It is recommended that you store the
    # date as a string if you don't need the time to the nearest
    # millisecond. That makes things a lot easier.
    def DateTools.serialize_time(time)
      if time.instance_of?(Time) then time = time.to_i end

      if (time < 0) then raise("time too early") end

      # convert to milliseconds before serialization
      s = (time*1000).to_s(36)

      if (s.length() > SERIALIZED_DATE_LEN) then raise("time too late") end

      # pad to 16 charactors
      s = "0" + s while (s.length() < SERIALIZED_DATE_LEN)

      return s
    end

    # The earliest date that can be stored in this format.
    MIN_SERIALIZED_DATE_STRING = DateTools.serialize_time(0)

    # Converts a string-encoded date into a millisecond time.
    def DateTools.deserialize_time(s)
      # remember to convert back to seconds
      return Time.at(s.to_i(36)/1000)
    end

    def DateTools.date_to_s(date, resolution = Resolution::MILLISECOND)
      return time_to_s(Time.parse(date), resolution)
    end
    
    
    # Converts a millisecond time to a string suitable for indexing.
    # 
    # time:: the date expressed as milliseconds since January 1, 1970,
    #     00:00:00 GMT resolution:: the desired resolution, see
    #     #round(long, DateTools.Resolution)
    # return:: a string in format _%Y%m%d%H%M%SSSS_ or shorter,
    #          depending on _resolution_
    def DateTools.time_to_s(time, resolution = Resolution::MILLISECOND)
      if time.instance_of?(Date) then time = Time.parse(time) end
      suffix = ""
      if (resolution == Resolution::MILLISECOND)
        # the suffix is the number of milliseconds if needed.
        suffix = ((time.to_f-time.to_f.floor)*1000).round.to_s
      end
      return time.strftime(resolution.format) + suffix
    end

    # Converts a string produced by _time_to_s_ or _date_to_s_ back to a
    # time, represented as the number of milliseconds since January 1, 1970,
    # 00:00:00 GMT.
    # 
    # str:: the date string to be converted
    # return:: the number of milliseconds since January 1, 1970, 00:00:00GMT
    def DateTools.s_to_time(str)
      year =        str.size >=  4 ? str[ 0.. 3].to_i : nil
      month =       str.size >=  6 ? str[ 4.. 5].to_i : nil
      day =         str.size >=  8 ? str[ 6.. 7].to_i : nil
      hour =        str.size >= 10 ? str[ 8.. 9].to_i : nil
      minute =      str.size >= 12 ? str[10..11].to_i : nil
      second =      str.size >= 14 ? str[12..13].to_i : nil
      microsecond = str.size >= 17 ? str[14..17].to_i*1000 : nil
      return Time.mktime(year, month, day, hour, minute, second, microsecond)
    end

    # Limit a date's resolution. For example, the date _2004-09-21 13:50:11_
    # will be changed to _2004-09-01 00:00:00_ when using
    # _Resolution.MONTH_. 
    # 
    # resolution:: The desired resolution of the date to be returned
    # return:: the date with all values more precise than _resolution_
    #  set to 0 or 1
    def DateTools.round(time, resolution)
      return s_to_time(time_to_s(time, resolution))
    end
    
    class Resolution < Parameter
      attr_accessor :format

      private :initialize

      def initialize(name, format)
          super(name)
          @format = format
      end

      YEAR        = Resolution.new("year",   "%Y")
      MONTH       = Resolution.new("month",  "%Y%m")
      DAY         = Resolution.new("day",    "%Y%m%d")
      HOUR        = Resolution.new("hour",   "%Y%m%d%H")
      MINUTE      = Resolution.new("minute", "%Y%m%d%H%M")
      SECOND      = Resolution.new("second", "%Y%m%d%H%M%S")
      MILLISECOND = Resolution.new("millisecond", "%Y%m%d%H%M%S")

    end
  end
end
