module RedmineHoptoadServer
  module Patches
    module IssueObserverPatch
      def self.included(base)
        base.class_eval do
          include InstanceMethods
          alias_method_chain :after_create, :notify_switch
        end
      end
      module InstanceMethods
        def after_create_with_notify_switch(issue)
          after_create_without_notify_switch issue unless issue.skip_notification?
        end
      end
    end
  end
end
