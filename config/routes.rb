
# API v1 (hoptoad)
post 'notices', :to => 'notices#index'

# API v2 (hoptoad / airbrake, xml based)
post 'notifier_api/v2/notices', :to => 'notices#index_v2'

