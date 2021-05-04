# Modified by SignalFx
module Sidekiq
  module Tracer
    class ClientMiddleware
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

      def call(worker_class, job, queue, redis_pool)
        scope = tracer.start_active_span(
          operation_name(job), tags: tags(job, 'client')
        )
        inject(scope.span, job) if opts.fetch(:propagate_context, true)
        yield
      rescue Exception => e
        if scope&.span.respond_to?(:record_exception)
          # SignalFx custom error analyzer
          scope.span.record_exception(e)
        elsif scope&.span
          scope.span.set_tag('error', true)
          scope.span.log_kv(event: 'error', :'error.object' => e)
        end

        raise
      ensure
        scope.close if scope
      end

      private

      def inject(span, job)
        carrier = {}
        tracer.inject(span.context, OpenTracing::FORMAT_TEXT_MAP, carrier)
        job[TRACE_CONTEXT_KEY] = carrier
      end
    end
  end
end
