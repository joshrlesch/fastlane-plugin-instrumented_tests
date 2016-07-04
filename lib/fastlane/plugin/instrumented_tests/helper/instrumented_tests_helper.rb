module Fastlane
  module Helper
    class InstrumentedTestsHelper
      # class methods that you define here become available in your action
      # as `Helper::InstrumentedTestsHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the instrumented_tests plugin helper!")
      end
    end
  end
end
