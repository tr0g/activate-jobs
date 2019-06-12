source 'https://rubygems.org'

ruby '2.3.1' # Version in .ruby-version must match

gem 'rails', '3.2.22'
gem 'mysql2', '< 0.4'

gem 'thin' 

gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jquery-tablesorter'
gem 'jcrop-rails-v2', '~> 0.9.12'

# ldap integration
gem 'ruby-net-ldap', require: 'net/ldap'

# generate calendar feeds
gem 'icalendar'

# authentication
gem 'authlogic'
gem 'scrypt', '3.0.6' # dependency of authlogic, which isn't automatically resolved
gem 'bcrypt-ruby', '3.0.0'

# image upload
gem 'paperclip'

# model versioning (used for payform items)
# gem 'vestal_versions', git: 'https://github.com/laserlemon/vestal_versions.git'
gem 'paper_trail', '~> 3.0.5'

gem 'htmlentities'

# deliver mail asynchronously
gem 'mail'
gem 'delayed_job_active_record', '~> 4.0.2'
gem 'delayed_job_web', '~> 1.2.9'
gem 'daemons', '~> 1.1.9'

# scheduled cron jobs
gem 'whenever'

# authentication
gem 'rubycas-client-rails'
gem 'rubycas-client', '2.2.1'

# deployment
gem 'capistrano'

# removed these plugins as they are deprecated
gem 'dynamic_form' # needed for f.error_messages
gem 'simple_form'  # replaces multiple_select
# replace ActiveSupport::Memoizable
gem 'memoist'

gem 'activerecord-import'

group :development, :test do
  gem 'rspec-rails', '~> 3.0.0'
  gem 'test-unit'
  gem 'minitest'
  gem 'factory_girl_rails'
  gem 'annotate' # https://github.com/ctran/annotate_models add info headers
  gem 'fuubar'
  gem 'timecop'
end

group :development do
  gem 'pry-rails'
  gem 'pry-byebug'
  gem 'letter_opener'
  gem 'faker'
  gem 'better_errors'
  gem 'binding_of_caller' # Enables the REPL in better_errors
  gem 'ruby-progressbar'
  gem 'guard-rspec', require: false
end

group :test do
  gem 'rspec'
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'database_cleaner'
  gem 'codeclimate-test-reporter', require: false
end

group :assets do
  # gem 'sass-rails',   '~> 3.2.3' # using sass-rails below
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '>= 1.0.3'
end

# For Twitter-bootstrap (also use sass-rails), https://github.com/twbs/bootstrap-sass
gem 'bootstrap-sass', '~> 3.1.1'
gem 'font-awesome-rails'
#gem 'font-awesome-sass', '~> 4.2.0'

# Starting with bootstrap-sass v3.1.1.1, due to the structural changes from upstream you will need these backported asset pipeline gems on Rails 3.2.
gem 'sprockets-rails', :require => 'sprockets/railtie'
gem 'sprockets'
gem 'sass-rails'
