require 'spec_helper'

describe 'rk_tomcat', :type => :class do
  context 'with defaults for all parameters' do
    it { should_not compile }
    #it do
    #  expect {
    #    is_expected.to compile
    #  }.to raise_error(Puppet::PreformattedError, /Must pass stack to Class[Rk_tomcat]/)
    #end
    #it { should contain_class('wget') }

    #it { should contain_class('rk_tomcat')}
    #it { should contain_rk_tomcat__deploy}

  end
end

describe 'rk_tomcat', :type => :class do
  context 'with parameter mode set to "provision"' do
    let(:facts) { {:osfamily => 'Amazon'} }
    let (:params) do
      {
        :mode  => 'provision',
        :stack => 'rk-prod-app',
      }
    end
    it { should contain_class('wget')}
    it { should contain_class('rk_tomcat')}
    it { should contain_class('rk_tomcat::fonts')}
    it { should contain_class('rk_tomcat::goss')}
    it { should contain_class('rk_tomcat::java')}
    it { should contain_class('rk_tomcat::limits')}
    it { should contain_class('rk_tomcat::newrelic')}
    it { should contain_class('rk_tomcat::newrelic::provision')}
  end
end

describe 'rk_tomcat', :type => :class do
  context 'with parameter mode set to "deploy"' do
    let(:facts) { {:osfamily => 'Amazon'} }
    let (:params) do
      {
        :mode  => 'deploy',
        :stack => 'rk-prod-app'
      }
    end
    it { should contain_class('wget')}
    it { should contain_class('threatstack').with(
      'deploy_key'      => 'd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yAA',
      )
    }
    it { should contain_class('rk_tomcat')}
    it { should contain_class('rk_tomcat::deploy')}
    it { should contain_class('rk_tomcat::tomcat')}
    it { should contain_class('rk_tomcat::auth')}
    it { should contain_class('rk_tomcat::kinesis')}
    it { should contain_class('rk_tomcat::newrelic::deploy')}
    it { should contain_class('rk_tomcat::rsyslog')}
    it { should contain_class('rk_tomcat::rsyslog::deploy')}
  end
end
