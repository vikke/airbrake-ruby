module Airbrake
  module Filters
    ##
    # Attaches thread & fiber local variables along with general thread
    # information.
    class ThreadFilter
      ##
      # @return [Integer]
      attr_reader :weight

      ##
      # @return [Array<Symbol>] the list of ignored fiber variables
      IGNORED_FIBER_VARIABLES = [
        # https://github.com/airbrake/airbrake-ruby/issues/204
        :__recursive_key__,

        # https://github.com/rails/rails/issues/28996
        :__rspec
      ].freeze

      def initialize
        @weight = 110
      end

      def call(notice)
        th = Thread.current
        thread_info = {}

        if (vars = thread_variables(th)).any?
          thread_info[:thread_variables] = vars
        end

        if (vars = fiber_variables(th)).any?
          thread_info[:fiber_variables] = vars
        end

        # Present in Ruby 2.3+.
        if th.respond_to?(:name) && (name = th.name)
          thread_info[:name] = name
        end

        add_thread_info(th, thread_info)

        notice[:params][:thread] = thread_info
      end

      private

      def thread_variables(th)
        th.thread_variables.map.with_object({}) do |var, h|
          next if (value = th.thread_variable_get(var)).is_a?(IO)
          h[var] = value
        end
      end

      def fiber_variables(th)
        th.keys.map.with_object({}) do |key, h|
          next if IGNORED_FIBER_VARIABLES.any? { |v| v == key }
          next if (value = th[key]).is_a?(IO)
          h[key] = value
        end
      end

      def add_thread_info(th, thread_info)
        thread_info[:self] = th.inspect
        thread_info[:group] = th.group.list.map(&:inspect)
        thread_info[:priority] = th.priority

        thread_info[:safe_level] = th.safe_level unless Airbrake::JRUBY
      end
    end
  end
end
