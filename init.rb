Redmine::Plugin.register :redmine_hoptoad_server do
  name 'Redmine Hoptoad Server plugin'
  author 'Jan Schulz-Hofen, Planio GmbH'
  author_url 'https://plan.io/team/#jan'
  description 'Turns Redmine into an Airbrake/Hoptoad compatible server, i.e. an API provider which can be used with the Airbrake gem or the hoptoad_notifier plugin.'
  url 'http://github.com/yeah/redmine_hoptoad_server'
  version '1.0.0'
  hidden(true) if respond_to?(:hidden) # hide plugin in Planio

  requires_redmine :version_or_higher => '2.4.0'
end

begin
  require 'nokogiri'
rescue LoadError
  Rails.logger.error "Nokogiri gem not found, parsing hoptoad API v2 requests will be sub-optimal"
end

Rails.configuration.to_prepare do
  require_dependency 'redmine_hoptoad_server/patches/issue_patch'
end

