# Modified by SignalFx
module Sidekiq
  module Tracer
    class ServerMiddleware
      include Commons

      attr_reader :tracer, :opts

      if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.7.0')
        def initialize(args)
          @tracer = args[:tracer]
          @opts = args.fetch(:opts, {})
        end
      else
        def initialize(tracer: nil, opts: {})
          @tracer = tracer
          @opts = opts
        end
      end

      def call(worker, job, queue)
        parent_span_context = extract(job) if opts.fetch(:propagate_context, true)

        scope = tracer.start_active_span(
          operation_name(job),
          child_of: parent_span_context,
          tags: tags(job, 'server')
        )

        yield
      rescue Exception => e
        if scope
          scope.span.record_exception(e)
        end
        raise
      ensure
        scope.close if scope
      end

      private

      def extract(job)
        carrier = job[TRACE_CONTEXT_KEY]
        return unless carrier

        tracer.extract(OpenTracing::FORMAT_TEXT_MAP, carrier)
      end
    end
  end
end
