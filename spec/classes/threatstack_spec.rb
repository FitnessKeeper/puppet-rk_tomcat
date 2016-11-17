require 'spec_helper'

describe 'rk_tomcat::threatstack', :type => :class do
  context 'with defaults for all parameters' do
    it { should_not compile }
  end
end

describe 'rk_tomcat::threatstack', :type => :class do
  context 'with parameter mode set to "deploy"' do
    let(:facts) { {:osfamily => 'Amazon'} }
    let (:params) do
      {
        :deploy_key => 'd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yAA'
      }
    end
    it { should contain_class('threatstack').with(
      'deploy_key'      => 'd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yAA',
      'configure_agent' => 'false',
      )
    }
    it { should contain_file('/etc/cloud/cloud.cfg.d/99_threatstack.cfg').with(
      'ensure' => 'file',
      )
    }
    it { should contain_file('/etc/cloud/cloud.cfg.d/99_threatstack.cfg').with_content(/runcmd:/)
    }
    it { should contain_file('/etc/cloud/cloud.cfg.d/99_threatstack.cfg').with_content(/deploy-key=d3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yd3adk3yAA/)}
  end
end
