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
    let (:params) do
      {
        :mode  => 'provision',
        :stack => 'rk-prod-app'
      }
    end
    it { should contain_class('wget')}
    it { should contain_class('rk_tomcat')}
    it { should contain_class('rk_tomcat::fonts')}
    it { should contain_class('rk_tomcat::java')}
  end
end

describe 'rk_tomcat', :type => :class do
  context 'with parameter mode set to "deploy"' do
    let (:params) do
      {
        :mode  => 'deploy',
        :stack => 'rk-prod-app'
      }
    end
    it { should contain_class('wget')}
    it { should contain_class('rk_tomcat')}
    it { should contain_class('rk_tomcat::deploy')}
    it { should contain_class('rk_tomcat::tomcat')}
  end
end
