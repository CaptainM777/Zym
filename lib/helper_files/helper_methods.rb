# Takes the given time string argument, in a format similar to '5d2h15m45s' and returns its representation in
# a number of seconds.
# @param  [String]  str the string to parse into a number of seconds
# @return [Integer]     the number of seconds the given string is equal to, or 0 if it cannot be parsed properly
def parse_time(str)
  seconds = 0
  str.scan(/\d+ *[Dd]/).each { |m| seconds += (m.to_i * 24 * 60 * 60) }
  str.scan(/\d+ *[Hh]/).each { |m| seconds += (m.to_i * 60 * 60) }
  str.scan(/\d+ *[Mm]/).each { |m| seconds += (m.to_i * 60) }
  str.scan(/\d+ *[Ss]/).each { |m| seconds += (m.to_i) }
  seconds
end

# Takes the given number of seconds and converts into a string that describes its length (i.e. 3 hours,
# 4 minutes and 5 seconds, etc.)
# @param  [Integer] secs the number of seconds to convert
# @return [String]       the length of time described
def time_string(secs)
  dhms = ([secs / 86400] + Time.at(secs).utc.strftime('%H|%M|%S').split("|").map(&:to_i)).zip(['day', 'hour', 'minute', 'second'])
  dhms.shift while dhms[0][0].round == 0
  dhms.pop while dhms[-1][0].round == 0
  dhms.map! { |(v, s)| "#{v} #{s}#{v == 1 ? nil : 's'}" }
  return dhms[0] if dhms.size == 1
  "#{dhms[0..-2].join(', ')} and #{dhms[-1]}"
end
