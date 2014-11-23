if SqlPatches.class_exists?("RSolr::Connection") && RSolr::VERSION[0] != "0" #  requires at least v1.0.0
  class RSolr::Connection
    alias_method :execute_without_profiling, :execute
    def execute_with_profiling(client, request_context)
      current = ::Rack::MiniProfiler.current
      return execute_without_profiling(client, request_context) unless current && current.measure

      start        = Time.now
      result       = execute_without_profiling(client, request_context)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)

      data = "#{request_context[:method].upcase} #{request_context[:uri]}"
      if request_context[:method] == :post and request_context[:data]
        if request_context[:headers].include?("Content-Type") and request_context[:headers]["Content-Type"] == "text/xml"
          # it's xml, unescaping isn't needed
          data << "\n#{request_context[:data]}"
        else
          data << "\n#{Rack::Utils.unescape(request_context[:data])}"
        end
      end
      ::Rack::MiniProfiler.record_sql(data, elapsed_time)

      result
    end
    alias_method :execute, :execute_with_profiling
  end
end
