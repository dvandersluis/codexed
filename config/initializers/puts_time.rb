require 'term/ansicolor'

def puts_time(desc, &block)
  result = nil
  time = Benchmark.ms { result = yield }
  ftime = ((time >= 1000) ? ("%.3fs" % (time / 1000.0)) : ("%dms" % time))
  RAILS_DEFAULT_LOGGER.debug Color.red("#{desc}: #{ftime}")
  result
end