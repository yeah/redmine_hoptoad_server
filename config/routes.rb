ActionController::Routing::Routes.draw do |map|

  map.with_options(:controller => 'notices', :method => :post) do |m|
    m.connect 'notices', :action => 'index'
    m.connect 'notifier_api/v2/notices', :action => 'index_v2'
  end

end