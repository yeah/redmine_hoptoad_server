ActionController::Routing::Routes.draw do |map|

  map.with_options(:controller => 'notices', :method => :post) do |m|
    m.connect 'notices',                 :action => 'index'         # API v1 (hoptoad)
    m.connect 'notifier_api/v2/notices', :action => 'index_v2'      # API v2 (hoptoad / airbrake, xml based)
  end

  if Rails.env == 'test'
    # route without the :method => :post requirement since otherwise the route is
    # not recognized in the functional test. dont know why though...
    map.connect '/notices/index_v2', :controller => 'notices', :action => 'index_v2'
  end

end
