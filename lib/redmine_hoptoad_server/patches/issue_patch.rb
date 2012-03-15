module RedmineHoptoadServer
  module Patches
    module IssuePatch
      def self.included(base)
        base.class_eval do
          attr_accessor :skip_notification
          def skip_notification?
            @skip_notification == true
          end
        end
      end
    end
  end
end
