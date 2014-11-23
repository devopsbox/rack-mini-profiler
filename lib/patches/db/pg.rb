# PG patches, keep in mind exec and async_exec have a exec{|r| } semantics that is yet to be implemented
if SqlPatches.class_exists? "PG::Result"

  class PG::Result
    alias_method :each_without_profiling, :each
    alias_method :values_without_profiling, :values

    def values(*args, &blk)
      return values_without_profiling(*args, &blk) unless @miniprofiler_sql_id

      start        = Time.now
      result       = values_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)

      @miniprofiler_sql_id.report_reader_duration(elapsed_time)
      result
    end

    def each(*args, &blk)
      return each_without_profiling(*args, &blk) unless @miniprofiler_sql_id

      start        = Time.now
      result       = each_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)

      @miniprofiler_sql_id.report_reader_duration(elapsed_time)
      result
    end
  end

  class PG::Connection
    alias_method :exec_without_profiling, :exec
    alias_method :async_exec_without_profiling, :async_exec
    alias_method :exec_prepared_without_profiling, :exec_prepared
    alias_method :send_query_prepared_without_profiling, :send_query_prepared
    alias_method :prepare_without_profiling, :prepare

    def prepare(*args,&blk)
      # we have no choice but to do this here,
      # if we do the check for profiling first, our cache may miss critical stuff

      @prepare_map ||= {}
      @prepare_map[args[0]] = args[1]
      # dont leak more than 10k ever
      @prepare_map = {} if @prepare_map.length > 1000

      current = ::Rack::MiniProfiler.current
      return prepare_without_profiling(*args,&blk) unless current && current.measure

      prepare_without_profiling(*args,&blk)
    end

    def exec(*args,&blk)
      current = ::Rack::MiniProfiler.current
      return exec_without_profiling(*args,&blk) unless current && current.measure

      start        = Time.now
      result       = exec_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)
      record       = ::Rack::MiniProfiler.record_sql(args[0], elapsed_time)
      result.instance_variable_set("@miniprofiler_sql_id", record) if result

      result
    end

    def exec_prepared(*args,&blk)
      current = ::Rack::MiniProfiler.current
      return exec_prepared_without_profiling(*args,&blk) unless current && current.measure

      start        = Time.now
      result       = exec_prepared_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)
      mapped       = args[0]
      mapped       = @prepare_map[mapped] || args[0] if @prepare_map
      record       = ::Rack::MiniProfiler.record_sql(mapped, elapsed_time)
      result.instance_variable_set("@miniprofiler_sql_id", record) if result

      result
    end

    def send_query_prepared(*args,&blk)
      current = ::Rack::MiniProfiler.current
      return send_query_prepared_without_profiling(*args,&blk) unless current && current.measure

      start        = Time.now
      result       = send_query_prepared_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)
      mapped       = args[0]
      mapped       = @prepare_map[mapped] || args[0] if @prepare_map
      record       = ::Rack::MiniProfiler.record_sql(mapped, elapsed_time)
      result.instance_variable_set("@miniprofiler_sql_id", record) if result

      result
    end

    def async_exec(*args,&blk)
      current = ::Rack::MiniProfiler.current
      return exec_without_profiling(*args,&blk) unless current && current.measure

      start        = Time.now
      result       = exec_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)
      record       = ::Rack::MiniProfiler.record_sql(args[0], elapsed_time)
      result.instance_variable_set("@miniprofiler_sql_id", record) if result

      result
    end

    alias_method :query, :exec
  end

  SqlPatches.patched = true
end
