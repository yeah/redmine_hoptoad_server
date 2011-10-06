require 'redmine'

begin
  gem 'nokogiri'
  require 'nokogiri'
rescue LoadError
  Rails.logger.error "Nokogiri gem not found, parsing hoptoad API v2 requests will be sub-optimal"
end

Redmine::Plugin.register :redmine_hoptoad_server do
  name 'Redmine Hoptoad Server plugin'
  author 'Jan Schulz-Hofen, Planio GmbH'
  description 'Turns Redmine into a Hoptoad server, i.e. an API provider which can be used with the hoptoad_notifier. See http://github.com/yeah/redmine_hoptoad_server'
  version '0.0.1'
end
