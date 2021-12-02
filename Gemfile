source 'https://rubygems.org'

if puppetversion = ENV['PUPPET_VERSION']
  gem 'puppet', puppetversion, :require => false
else
  gem 'puppet', '~> 7.12'
end

gem 'puppetlabs_spec_helper', '>= 0.8.2'
gem 'puppet-lint', '>= 1.0.0'
gem 'ruby-augeas', '>= 0.5'
gem 'facter', '>= 1.7.0'
gem 'librarian-puppet', '~> 3.0'
gem 'deep_merge', '~> 1.2'
gem 'aws-sdk', '~> 3'
gem 'aws-instmd', '~> 0.1'
gem 'process_lock', '~> 0.1'

group :development, :test do
  gem 'dotenv', '~> 2.0'
  gem 'rake', '~> 10.4'
end
