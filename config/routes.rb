Shifts::Application.routes.draw do |map|

  map.resources :shifts_tasks

  map.resources :tasks, :member => {:make_entry => :post}

  map.resources :template_time_slots

  map.resources :stickies

  map.resources :announcements

  map.resources :links

  map.resources :repeating_events

  map.resources :calendars, :member => {:toggle => :post, :prepare_copy => :get, :copy => :post, :apply_schedule => [:get, :post]}, :collection => {:prepare_wipe_range => :get, :wipe_range => :post}

  map.resources :punch_clock_sets

  map.with_options :controller => 'first_run' do |f|
    f.first_app_config 'firstrun/first_app_config', :action => 'new_app_config', :method => 'get'
    f.first_department 'firstrun/first_department', :action => 'new_department', :method => 'get'
    f.first_user 'firstrun/first_user', :action => 'new_user', :method => 'get'
    f.create_first_app_config 'firstrun/create_first_app_config', :action => 'create_app_config', :method => 'post'
    f.create_first_department 'firstrun/create_first_department', :action => 'create_department', :method => 'post'
    f.create_first_user 'firstrun/create_first_user', :action => 'create_user', :method => 'post'
  end

  map.login "login", :controller => 'user_sessions', :action => 'new'
  map.logout "logout", :controller => 'user_sessions', :action => 'destroy'

  map.resources :app_configs, :only => [:edit, :update]

  map.edit_app_config "app_config", :controller => 'app_configs', :action => 'edit', :method => 'get'

  map.resources :punch_clocks
  map.resources :restrictions
  map.email_reminders "email_reminders", :controller => 'payforms', :action => 'email_reminders'
  map.reminders_advanced_options "reminders_advanced_options", :controller => 'payforms', :action => 'reminders_advanced_options'
  map.warnings_advanced_options  "warnings_advanced_options", :controller => 'payforms', :action => 'warnings_advanced_options'

  #TODO: get rid of sessions controller and move logout action to user_session controller and name it cas_logout
  map.cas_logout "cas_logout", :controller => 'sessions', :action => 'logout'

   # routes for calendar_feeds
  map.calendar_feed 'calendar_feeds/grab/:user_id/:token.:format', :controller => 'calendar_feeds', :action => 'grab'
  map.resources :calendar_feeds

  # routes for managing superusers
  map.superusers "superusers", :controller => 'superusers'
  map.add_superusers "superusers/add", :controller => 'superusers', :action => 'add'
  map.remove_superusers "superusers/remove", :controller => 'superusers', :action => 'remove'

  map.resources :user_sessions

  map.resources :password_resets

  map.resources :user_configs, :only => [:edit, :update]

  map.resources :sub_requests
  map.resources :notices, :collection => {:archive => :get}

  map.resources :stats,
              :collection => {:for_user => [:post, :get], :for_location => [:post, :get], :index => [:post, :get]}

  map.resources :payforms,
              :collection => {:index => [:post, :get], :prune => :delete, :go => :get, :search => [:post, :get]},
              :member => {:submit => :get, :unsubmit => :get, :approve => :get, :skip => :get, :unskip => :get, :unapprove => :get, :print => :get},
              :shallow => true do |payform|
                  payform.resources :payform_items, :member => {:delete => :get}
              end

  map.resources :payform_item_sets
  map.resources :payform_sets
  map.resources :department_configs, :only => [:edit, :update]

  map.resources :payforms,
                :collection => { :prune => :delete, :go => :get, :search => :post},
                :member => {:submit => :get, :unsubmit => :get, :approve => :get, :skip => :get, :unskip => :get, :unapprove => :get, :print => :get},
                :shallow => true do |payform|
    payform.resources :payform_items, :member => {:delete => :get}
  end

  map.resources :payform_items

  map.resources :time_slots, :member => {:rerender => :get} #TODO: What should this be nested under, if anything?

  map.resources :shifts, :new => {:unscheduled => :get, :ajax_create => :post}, :member => {:rerender => :get}, :collection => {:show_active => :get, :show_unscheduled => :get}, :shallow => true do |shifts|
    shifts.resource :report do |report|
      report.resources :report_items
    end
    #NOTE: "sub_requests" is a clearer model name, we use subs for routing
    shifts.resources :sub_requests, :member => {:take => :put, :get_take_info => :get},
                                    :as => "subs"
  end


  map.resources :requested_shifts
  map.resources :templates

  map.resources :users, :collection => {:update_superusers => :post}, :member => {:toggle => [:get, :post]} do |user|
    user.resources :punch_clocks
  end
  map.resources :reports, :except => [:new], :member => {:popup => :get} do |report|
    report.resources :report_items
  end

  map.resources :requested_shifts
  map.resources :templates

  map.resources :public_view, :member => {:for_location => [:post, :get]}

  map.resources :users, :collection => {:update_superusers => :post}, :member => {:toggle => [:get, :post]} do |user|
    user.resources :punch_clocks
  end

  #TODO Fix report items routing, this is temporary
  map.resources :locations, :except => [:index, :show, :edit, :find_allowed_locations, :new, :update, :create, :destroy], :collection => {:display_report_items => [:get, :post], :toggle => [:get, :post]}
  #map.resources :locations, :collection => {:display_report_items => [:post, :get], :toggle => [:post, :get], :index => [:post, :get]}, :except => [:index, :show, :edit, :find_allowed_locations, :new, :update, :create, :destroy]

  map.resources :data_types do |data_type|
    data_type.resources :data_fields
    data_type.resources :data_objects, :only => [:new, :create, :index]
  end

  map.resources :data_objects do |data_object|
    data_object.resources :data_entries, :member => {:edit => :put, :update => :put}
  end

  map.resources :departments, :shallow => true do |departments|
    departments.resources :users, :collection => {:mass_add => :get, :mass_create => :post, :restore => :post, :autocomplete => :get, :search => :post, :import => :get, :save_import => :post}
    departments.resources :loc_groups
    departments.resources :locations
    departments.resources :roles, :member => {:users => [:post,:get] }
    departments.resources :categories
  end

  map.resources :user_profile_fields
  map.resources :user_profiles, :collection => {:search => :post}
  map.facebook "/facebook", :controller => "user_profiles", :action => "facebook"
  map.email_group "/email_group", :controller => "shifts", :action => "email_group"

  map.resources :punch_clock_sets

  # permission is always created indirectly so there is only index method that lists them
  map.resources :permissions, :only => :index
  map.resources :stats, :collection => {:for_user => [:post, :get], :for_location => [:post, :get], :index => [:post, :get]}

  #map.report_items 'report_items/for_location', :controller => 'report_items', :action => 'for_location'

  map.dashboard '/dashboard', :controller => 'dashboard', :action => 'index'
  map.access_denied '/access_denied', :controller => 'application', :action => 'access_denied'

  map.rt_add_job '/rt', :controller => 'hooks', :action => 'add_job'

	map.resources :templates, :collection => {:update_locations => :post} do |template|
		template.resources :requested_shifts
		template.resources :shift_preferences
		template.resources :template_time_slots
  end

  map.root :controller => "dashboard"

  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'

  # TODO: What are these?
  # map.connect '/reports/http://www.google.com', :controller => "reports", :action => "redirect_to_external_url"
  # map.connect '/reports/http://weke.its.yale.edu/wiki/index.php?title=Special%3ASearch&search=', :controller => "reports", :action => "redirect_to_external_url"

  map.test_new_lists '/test_new_lists', :controller => 'reports', :action => 'tasks_and_objects_list'
  map.update_data_objects '/update_data_objects', :controller => 'data_objects', :action => 'update_data_objects'
  map.active_tasks '/active_tasks', :controller => 'tasks', :action => 'active_tasks'

end
