# frozen_string_literal: true

require 'open3'
require 'fileutils'

def install_bundler
  message('INSTALL BUNDLER')
  run('gem install bundler')
end

def install_facter_acceptance_dependencies
  message('INSTALL FACTER ACCEPTANCE DEPENDENCIES')
  run('bundle install')
end

def initialize_beaker
  beaker_platform_with_options = platform_with_options(beaker_platform)

  message('BEAKER INITIALIZE')
  run("beaker init -h #{beaker_platform_with_options} -o #{File.join('config', 'aio', 'options.rb')}")

  message('BEAKER PROVISION')
  run('beaker provision')
end

def beaker_platform
  {
    'ubuntu-18.04' => 'ubuntu1804-64a',
    'ubuntu-16.04' => 'ubuntu1604-64a',
    'ubuntu-20.04' => 'ubuntu2004-64a',
    'macos-10.15' => 'osx1015-64a',
    'windows-2016' => 'windows2016-64a',
    'windows-2019' => 'windows2019-64a'
  }[HOST_PLATFORM]
end

def platform_with_options(platform)
  return "\"#{platform}{hypervisor=none,hostname=localhost,is_cygwin=false}\"" if platform.include? 'windows'

  "#{platform}{hypervisor=none\\,hostname=localhost}"
end

def install_puppet_agent
  message('INSTALL PUPPET AGENT')

  beaker_puppet_root, = run('bundle info beaker-puppet --path')
  presuite_file_path = File.join(beaker_puppet_root.chomp, 'setup', 'aio', '010_Install_Puppet_Agent.rb')

  run("beaker exec pre-suite --pre-suite #{presuite_file_path} --preserve-state", './', env_path_var)
end

def puppet_bin_dir
  return '/opt/puppetlabs/puppet/bin' unless HOST_PLATFORM.include? 'windows'

  'C:\\Program Files\\Puppet Labs\\Puppet\\bin'
end

def puppet_ruby
  return '/opt/puppetlabs/puppet/bin/ruby' unless HOST_PLATFORM.include? 'windows'

  'C:\\Program Files\\Puppet Labs\\Puppet\\puppet\\bin\\ruby.exe'
end

def facter_lib_path
  return '/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/facter' unless HOST_PLATFORM.include? 'windows'

  'C:\\Program Files\\Puppet Labs\\Puppet\\puppet\\lib\\ruby\\vendor_ruby\\facter'
end

def env_path_var
  HOST_PLATFORM.include?('windows') ? { 'PATH' => "#{puppet_bin_dir};#{ENV['PATH']}" } : {}
end

def install_facter
  message('OVERWRITE FACTER FROM PUPPET AGENT')

  Dir.chdir('../') do
    run("\'#{puppet_ruby}\' install.rb --bindir=#{puppet_bin_dir} --sitelibdir=#{facter_lib_path.gsub('facter', '')}")
  end
end

def run_acceptance_tests
  message('RUN ACCEPTANCE TESTS')

  run('beaker exec tests --test-tag-exclude=server,facter_3 --test-tag-or=risk:high,audit:high', './', env_path_var)
end

def message(message)
  message_length = message.length
  total_length = 130
  lines_length = (total_length - message_length) / 2
  result = ('-' * lines_length + ' ' + message + ' ' + '-' * lines_length)[0, total_length]
  puts "\n\n#{result}\n\n"
end

def run(command, dir = './', env = {})
  puts command
  output = ''
  status = 0
  Open3.popen2e(env, command, chdir: dir) do |_stdin, stdout_and_err, wait_thr|
    stdout_and_err.each do |line|
      puts line
      output += line
    end
    status = wait_thr.value
  end
  [output, status]
end

ENV['DEBIAN_DISABLE_RUBYGEMS_INTEGRATION'] = 'no_warnings'
ACCEPTANCE_PATH = File.join(ENV['FACTER_4_ROOT'], 'acceptance')
HOST_PLATFORM = ARGV[0]

install_bundler

Dir.chdir(ACCEPTANCE_PATH) do
  install_facter_acceptance_dependencies
  initialize_beaker
  install_puppet_agent
  install_facter

  _, status = run_acceptance_tests
  exit(status.exitstatus)
end
