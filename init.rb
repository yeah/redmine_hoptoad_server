require 'redmine'

Redmine::Plugin.register :redmine_hoptoad_server do
  name 'Redmine Hoptoad Server plugin'
  author 'Jan Schulz-Hofen'
  description 'This plugin turns Redmin into a Hoptoad server, i.e. an API provider which can be used with the hoptoad_notifier which is available at: http://www.hoptoadapp.com/'
  version '0.0.1'
end
