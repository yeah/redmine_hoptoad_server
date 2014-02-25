
# API v1 (hoptoad)
post 'notices', :to => 'notices#create'

# API v2 (hoptoad / airbrake, xml based)
post 'notifier_api/v2/notices', :to => 'notices#create_v2'

