require_dependency 'issue'

module RedmineHoptoadServer
  module Patches
    module IssuePatch
      def self.included(base)
        base.class_eval do
          attr_accessor :skip_notification
          def skip_notification?
            @skip_notification == true
          end

          def send_notification_with_skip_notification
            send_notification_without_skip_notification unless skip_notification?
          end
          alias_method_chain :send_notification, :skip_notification
        end
      end
    end
  end
end

Issue.send(:include, RedmineHoptoadServer::Patches::IssuePatch) unless Issue.included_modules.include?(RedmineHoptoadServer::Patches::IssuePatch)
