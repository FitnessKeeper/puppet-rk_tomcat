source 'https://rubygems.org'

if puppetversion = ENV['PUPPET_VERSION']
  gem 'puppet', puppetversion, :require => false
else
  gem 'puppet', '>= 4.2', '< 4.3'
end

gem 'puppetlabs_spec_helper', '>= 0.8.2'
gem 'puppet-lint', '>= 1.0.0'
gem 'facter', '>= 1.7.0'
gem 'librarian-puppet', '~> 2.2'
gem 'deep_merge', '~> 1'

group :development, :test do
  gem 'dotenv', '~> 2.0'
end
