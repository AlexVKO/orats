# =====================================================================================================
# Template for generating a chef cookbook
# =====================================================================================================

# ----- Helper functions and variables ----------------------------------------------------------------

require 'securerandom'

def generate_token
  SecureRandom.hex(64)
end

def git_config(field)
  command = "git config --global user.#{field}"
  git_field_value = run(command, capture: true).gsub("\n", '')
  default_value = "YOUR_#{field.upcase}"

  git_field_value.to_s.empty? ? default_value : git_field_value
end

app_name_upper = app_name.upcase
app_name_class = app_name.humanize

author_name = git_config 'name'
author_email = git_config 'email'

# ----- Nuke all of the rails code --------------------------------------------------------------------

puts
say_status  'shell', 'Removing all of the generated rails code...', :yellow
puts        '-'*80, ''; sleep 0.25

run 'rm -rf * .git .gitignore'

# ----- Install berkshelf -----------------------------------------------------------------------------

puts
say_status  'tool', 'Gem installing berkshelf, this may take a while...', :yellow
puts        '-'*80, ''; sleep 0.25

run 'gem install berkshelf'

# ----- Create cookbook -------------------------------------------------------------------------------

puts
say_status  'init', 'Creating skeleton cookbook...', :yellow
puts        '-'*80, ''; sleep 0.25

run "berks cookbook #{app_name}"

# ----- Move cookbook back one directory --------------------------------------------------------------

puts
say_status  'shell', 'Moving cookbook back one directory...', :yellow
puts        '-'*80, ''; sleep 0.25

run "mv #{app_name}/* ."
run "rm -rf #{app_name}"

# ----- Create the git repo ---------------------------------------------------------------------------

puts
say_status  'git', 'Creating initial commit...', :yellow
puts        '-'*80, ''; sleep 0.25

git :init
git add: '.'
git commit: "-m 'Initial commit'"

# ----- Create the license ----------------------------------------------------------------------------

puts
say_status  'root', 'Creating the license', :yellow
puts        '-'*80, ''; sleep 0.25

run 'rm -rf LICENSE'

file 'LICENSE' do <<-TEXT
The MIT License (MIT)

Copyright (c) #{Time.now.year} #{author_name} <#{author_email}>

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
TEXT
end

git add: '.'
git commit: "-m 'Add MIT license'"

# ----- Customize meta data ---------------------------------------------------------------------------

puts
say_status  'root', 'Changing metadata file', :yellow
puts        '-'*80, ''; sleep 0.25

puts author_name
puts author_email

gsub_file 'metadata.rb', 'YOUR_NAME', author_name
gsub_file 'metadata.rb', 'YOUR_EMAIL', author_email
gsub_file 'metadata.rb', 'All rights reserved', 'MIT LICENSE'

git add: '.'
git commit: "-m 'Change meta data in the metadata.rb file'"

# ----- Add application dependencies ------------------------------------------------------------------

puts
say_status  'root', 'Adding application dependencies...', :yellow
puts        '-'*80, ''; sleep 0.25

append_file 'Berksfile' do <<-CODE
cookbook 'postgresql', git: 'git://github.com/phlipper/chef-postgresql.git'
cookbook 'rvm', git: 'git://github.com/fnichol/chef-rvm'
CODE
end

git add: '.'
git commit: "-m 'Add dependencies to the Berksfile'"

append_file 'metadata.rb' do <<-CODE
# base
depends 'openssh', '~> 1.3.2'
depends 'user', '~> 0.3.0'
depends 'sudo', '~> 2.3.0'
depends 'runit', '~> 1.5.8'
depends 'fail2ban', '~> 2.1.2'
depends 'ufw', '~> 0.7.4'
depends 'swap', '~> 0.3.6'

# database
depends 'postgresql', '~> 0.13.0'

# cache
depends 'redisio', '~> 1.7.0'

# web
depends 'nginx', '~> 2.2.0'
depends 'logrotate', '~> 1.4.0'

# service/worker
depends 'git', '~> 2.9.0'
depends 'rvm', '~> 0.9.1'
depends 'nodejs', '~> 1.3.0'
CODE
end

git add: '.'
git commit: "-m 'Add dependencies to the metadata file'"

# ----- Install cookbooks locally ---------------------------------------------------------------------

puts
say_status  'tool', 'Berks installing the cookbooks, this may take a while...', :yellow
puts        '-'*80, ''; sleep 0.25

run 'berks install'

git add: '.'
git commit: "-m 'Change meta data in the metadata.rb file'"

# ----- Configure attributes file ---------------------------------------------------------------------

puts
say_status  'attr', 'Modifying the attributes file...', :yellow
puts        '-'*80, ''; sleep 0.25

random_ssh_port = rand(11000..55000)
random_username = SecureRandom.hex[0...8]

file 'attributes/default.rb' do <<-CODE
default[:#{app_name}][:base][:ssh_port] = '#{random_ssh_port}'
default[:#{app_name}][:base][:username] = '#{random_username}'
default[:#{app_name}][:base][:swap_size] = 1024 # MBs
default[:#{app_name}][:base][:ssh_key] = 'INSERT_YOUR_PUBLIC_SSH_KEY_HERE'

default[:#{app_name}][:database][:host] = 'localhost'
default[:#{app_name}][:database][:pool] = '25'
default[:#{app_name}][:database][:timeout] = '5000'

default[:#{app_name}][:cache][:host] = 'localhost'
default[:#{app_name}][:cache][:port] = '6379'
default[:#{app_name}][:cache][:database] = '0'

default[:#{app_name}][:web][:domain_name] = '#{app_name}.com'
default[:#{app_name}][:web][:redirect_no_www_to_www] = true

default[:#{app_name}][:service][:environment] = 'production'
default[:#{app_name}][:service][:deploy_action] = 'deploy' # 'force_deploy' or 'rollback'
default[:#{app_name}][:service][:ruby_version] = '2.1.0'
default[:#{app_name}][:service][:puma_threads_min] = '0'
default[:#{app_name}][:service][:puma_threads_max] = '16'
default[:#{app_name}][:service][:puma_workers] = '2'
default[:#{app_name}][:service][:mail_address] = 'smtp.#{app_name}.com'
default[:#{app_name}][:service][:mail_port] = '25'
default[:#{app_name}][:service][:mail_domain] = '#{app_name}.com'
default[:#{app_name}][:service][:mail_username] = 'info@#{app_name}.com'
default[:#{app_name}][:service][:mail_auth] = 'plain'
default[:#{app_name}][:service][:mail_startttls_auto] = 'true'
default[:#{app_name}][:service][:action_mailer_host] = 'www.#{app_name}.com'
default[:#{app_name}][:service][:action_mailer_default_email] = 'info@#{app_name}.com'
default[:#{app_name}][:service][:action_mailer_devise_default_email] = 'info@#{app_name}.com'

default[:#{app_name}][:worker][:sidekiq_concurrency] = '25'
CODE
end

git add: '.'
git commit: "-m 'Add tweakable settings to the attributes file'"

# ----- Create dummy data for the encrypted data bag --------------------------------------------------

puts
say_status  'data_bags', 'Creating dummy encrypted data bag...', :yellow
puts        '-'*80, ''; sleep 0.25

data_bag_path = "data_bags/#{app_name}_secrets"

run "mkdir -p #{data_bag_path}"

file "#{data_bag_path}/production.json" do <<-JSON
{
  "id": "production",
  "database_password": "<real password is protected>",
  "cache_password": "<real password is protected>",
  "mail_password": "<real password is protected>",
  "token_rails_secret": "<real token is protected>",
  "token_devise_secret": "<real token is protected>",
  "token_devise_pepper": "<real token is protected>"
}
JSON
end

git add: '.'
git commit: "-m 'Add the dummy data bag as a point of reference'"

# ----- Create nginx config ---------------------------------------------------------------------------

puts
say_status  'files', 'Creating nginx config...', :yellow
puts        '-'*80, ''; sleep 0.25

file 'templates/default/nginx_virtualhost.conf.erb' do <<-CONF
upstream #{app_name} {
  server unix:///tmp/puma.sock;
}

<% if node[:#{app_name}][:web][:redirect_no_www_to_www] %>
server {
  listen 80;
  server_name <%= node[:#{app_name}][:web][:domain_name] %>;
  return 301 $scheme://www.<%= node[:#{app_name}][:web][:domain_name] %>$request_uri;
}
<% end if %>

server {
  listen 80;
  server_name www.<%= node[:#{app_name}][:web][:domain_name] %>;
  root /home/#{random_username}/#{app_name}/current/public;

  error_page 404 /404.html;
  error_page 500 /500.html;
  error_page 502 503 504 /502.html;

  location ~ ^/(system|assets)/ {
    root /home/#{random_username}/#{app_name}/current/public;
    gzip_static on;
    expires 1y;
    add_header Cache-Control public;
    add_header ETag "";
    break;
  }

  try_files $uri @puma;

  location @puma {
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-Proto http;
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_redirect off;

    proxy_pass http://#{app_name};
    break;
  }
}
CONF
end

git add: '.'
git commit: "-m 'Add the nginx virtualhost config'"

# ----- Create system wide profile -------------------------------------------------------------------------

puts
say_status  'templates', 'Creating system wide profile config', :yellow
puts        '-'*80, ''; sleep 0.25

file 'templates/default/profile.erb' do <<-CONF
# /etc/profile: system-wide .profile file for the Bourne shell (sh(1))
# and Bourne compatible shells (bash(1), ksh(1), ash(1), ...).

if [ "$PS1" ]; then
  if [ "$BASH" ] && [ "$BASH" != "/bin/sh" ]; then
    # The file bash.bashrc already sets the default PS1.
    # PS1='\h:\w\$ '
    if [ -f /etc/bash.bashrc ]; then
      . /etc/bash.bashrc
    fi
  else
    if [ "`id -u`" -eq 0 ]; then
      PS1='# '
    else
      PS1='$ '
    fi
  fi
fi

# The default umask is now handled by pam_umask.
# See pam_umask(8) and /etc/login.defs.

if [ -d /etc/profile.d ]; then
  for i in /etc/profile.d/*.sh; do
    if [ -r $i ]; then
      . $i
    fi
  done
  unset i
fi

export RAILS_ENV='<%= node[:#{app_name}][:service][:environment] %>'

export <%= @cookbook_name.upcase %>_DATABASE_HOST='<%= node[:#{app_name}][:database][:host] %>'
export <%= @cookbook_name.upcase %>_DATABASE_NAME='<%= @cookbook_name.downcase %>'
export <%= @cookbook_name.upcase %>_DATABASE_USERNAME='postgres'
export <%= @cookbook_name.upcase %>_DATABASE_PASSWORD='<%= @database_password %>'
export <%= @cookbook_name.upcase %>_DATABASE_POOL='<%= node[:#{app_name}][:database][:pool] %>'
export <%= @cookbook_name.upcase %>_DATABASE_TIMEOUT='<%= node[:#{app_name}][:database][:timeout] %>'

export <%= @cookbook_name.upcase %>_CACHE_HOST='<%= node[:#{app_name}][:cache][:host] %>'
export <%= @cookbook_name.upcase %>_CACHE_DATABASE='<%= node[:#{app_name}][:cache][:database] %>'
export <%= @cookbook_name.upcase %>_CACHE_USERNAME='redis'
export <%= @cookbook_name.upcase %>_CACHE_PASSWORD='<%= @cache_password %>'

export <%= @cookbook_name.upcase %>_TOKEN_RAILS_SECRET='<%= @token_rails_secret %>'
export <%= @cookbook_name.upcase %>_TOKEN_DEVISE_SECRET='<%= @token_devise_secret %>'
export <%= @cookbook_name.upcase %>_TOKEN_DEVISE_PEPPER='<%= @token_devise_pepper %>'

export <%= @cookbook_name.upcase %>_SMTP_ADDRESS='<%= node[:#{app_name}][:service][:mail_address] %>'
export <%= @cookbook_name.upcase %>_SMTP_PORT='<%= node[:#{app_name}][:service][:mail_port] %>'
export <%= @cookbook_name.upcase %>_SMTP_DOMAIN='<%= node[:#{app_name}][:service][:mail_domain] %>'
export <%= @cookbook_name.upcase %>_SMTP_USERNAME='<%= node[:#{app_name}][:service][:mail_username] %>'
export <%= @cookbook_name.upcase %>_SMTP_PASSWORD='<%= @mail_password %>'
export <%= @cookbook_name.upcase %>_SMTP_AUTH='<%= node[:#{app_name}][:service][:mail_auth] %>'
export <%= @cookbook_name.upcase %>_SMTP_STARTTTLS_AUTO='<%= node[:#{app_name}][:service][:mail_startttls_auto] %>'

export <%= @cookbook_name.upcase %>_ACTION_MAILER_HOST='<%= node[:#{app_name}][:service][:action_mailer_host] %>'
export <%= @cookbook_name.upcase %>_ACTION_MAILER_DEFAULT_EMAIL='<%= node[:#{app_name}][:service][:action_mailer_default_email] %>'
export <%= @cookbook_name.upcase %>_ACTION_MAILER_DEVISE_DEFAULT_EMAIL='<%= node[:#{app_name}][:service][:action_mailer_devise_default_email] %>'

export <%= @cookbook_name.upcase %>_PUMA_THREADS_MIN='<%= node[:#{app_name}][:service][:puma_threads_min] %>'
export <%= @cookbook_name.upcase %>_PUMA_THREADS_MAX='<%= node[:#{app_name}][:service][:puma_threads_max] %>'
export <%= @cookbook_name.upcase %>_PUMA_WORKERS='<%= node[:#{app_name}][:service][:puma_workers] %>'

export <%= @cookbook_name.upcase %>_SIDEKIQ_CONCURRENCY='<%= node[:#{app_name}][:worker][:sidekiq_concurrency] %>'
CONF
end

git add: '.'
git commit: "-m 'Add the system wide profile config'"

# ----- Create environment library ------------------------------------------------------------------------

puts
say_status  'libraries', 'Creating environment library...', :yellow
puts        '-'*80, ''; sleep 0.25

file 'libraries/source_environment.rb' do <<-'CODE'
class Chef::Recipe::SourceEnvironment
  def self.from_etc_profile(env_prefix)
    Hash[
      File.read('/etc/profile')
        .gsub('export ', '')
        .gsub("'", '')
        .split("\n")
        .select { |key, _| key.match(/RAILS_ENV|#{env_prefix.upcase}/) }
        .map { |str| str.split('=') }
    ]
  end
end
CODE
end

git add: '.'
git commit: "-m 'Add the source_environment library'"

# ----- Create base recipe ----------------------------------------------------------------------------

puts
say_status  'recipes', 'Creating base recipe...', :yellow
puts        '-'*80, ''; sleep 0.25

file 'recipes/base.rb' do <<-'CODE'
# openssh

node.override[:openssh][:server][:port] = node[:app_name][:base][:ssh_port]
node.override[:openssh][:server][:password_authentication] = 'no'
node.override[:openssh][:server][:permit_root_login] = 'no'

include_recipe 'openssh'

# user

include_recipe 'user'

user_account node[:app_name][:base][:username] do
  ssh_keys [ node[:app_name][:base][:ssh_key] ]
end

# sudo

node.override[:authorization][:sudo][:users] = [ node[:app_name][:base][:username] ]
node.override[:authorization][:sudo][:passwordless] = true

include_recipe 'sudo'

# fail2ban

include_recipe 'fail2ban'

# ufw

node.override[:firewall][:rules] = [
  {
    'ssh' => {
      'port'=> node[:app_name][:base][:ssh_port]
    }
  },
  {
    'http' => {
      'port'=> '80'
    }
  }
]
include_recipe 'ufw'

# swapfile

swap_file '/mnt/swap' do
  size node[:app_name][:base][:swap_size]
end

# htop

package 'htop'
CODE
end

gsub_file 'recipes/base.rb', 'app_name', app_name

git add: '.'
git commit: "-m 'Add the base recipe'"

# ----- Create database recipe ------------------------------------------------------------------------

puts
say_status  'recipes', 'Creating database recipe...', :yellow
puts        '-'*80, ''; sleep 0.25

file 'recipes/database.rb' do <<-CODE
# This is where you will store a copy of your key on the chef-client
secret = Chef::EncryptedDataBagItem.load_secret('/etc/chef/encrypted_data_bag_secret')

# This decrypts the data bag contents of "#{app_name}_secrets/production.json" and uses the key defined at variable "secret"
encrypted_data_bag = Chef::EncryptedDataBagItem.load('#{app_name}_secrets', 'production', secret)

include_recipe '#{app_name}::base'
include_recipe 'postgresql'
include_recipe 'postgresql::client'
include_recipe 'postgresql::server'
include_recipe 'postgresql::libpq'

pg_user 'postgres' do
  privileges superuser: true, createdb: true, login: true
  password encrypted_data_bag['database_password']
end
CODE
end

git add: '.'
git commit: "-m 'Add the database recipe'"

# ----- Create cache recipe ---------------------------------------------------------------------------

puts
say_status  'recipes', 'Creating cache recipe...', :yellow
puts        '-'*80, ''; sleep 0.25

file 'recipes/cache.rb' do <<-CODE
include_recipe '#{app_name}::base'

node.override[:redisio][:mirror] = 'http://download.redis.io/releases'
node.override[:redisio][:version] = '2.8.3'
include_recipe 'redisio::install'
include_recipe 'redisio::enable'
CODE
end

git add: '.'
git commit: "-m 'Add the cache recipe'"

# ----- Create web recipe -----------------------------------------------------------------------------

puts
say_status  'recipes', 'Creating web recipe...', :yellow
puts        '-'*80, ''; sleep 0.25

file 'recipes/web.rb' do <<-'CODE'
include_recipe 'app_name::base'

# nginx

apt_repository 'nginx' do
  uri          'http://ppa.launchpad.net/nginx/stable/ubuntu'
  distribution node[:lsb][:codename]
  components   %w[main]
  keyserver    'keyserver.ubuntu.com'
  key          'C300EE8C'
  action       :add
end

node.override[:nginx][:gzip_comp_level] = '4'

include_recipe 'nginx'

template "#{node[:nginx][:dir]}/sites-available/#{cookbook_name}.conf" do
  source 'nginx_virtualhost.conf.erb'
  group node[:nginx][:user]
  owner node[:nginx][:user]
  mode '0644'
  variables({
    :cookbook_name => cookbook_name
  })
end

nginx_site "#{cookbook_name}.conf"

include_recipe 'logrotate'

logrotate_app 'nginx' do
  cookbook 'logrotate'
  path ["#{node[:nginx][:log_dir]}/access.log", "#{node[:nginx][:log_dir]}/error.log"]
  options ['missingok', 'notifempty']
  frequency 'daily'
  create '0644 root adm'
  rotate 365
end
CODE
end

gsub_file 'recipes/web.rb', 'app_name', app_name

git add: '.'
git commit: "-m 'Add the web recipe'"

# ----- Create service recipe -----------------------------------------------------------------------------

puts
say_status  'recipes', 'Creating service recipe...', :yellow
puts        '-'*80, ''; sleep 0.25

file 'recipes/service.rb' do <<-'CODE'
secret = Chef::EncryptedDataBagItem.load_secret('/etc/chef/encrypted_data_bag_secret')
encrypted_data_bag = Chef::EncryptedDataBagItem.load('app_name_secrets', 'production', secret)

include_recipe 'app_name::base'

# environment variables

template '/etc/profile' do
  source 'profile.erb'
  variables({
    :cookbook_name => cookbook_name,
    :database_password => encrypted_data_bag['database_password'],
    :cache_password => encrypted_data_bag['cache_password'],
    :mail_password => encrypted_data_bag['mail_password'],
    :token_rails_secret => encrypted_data_bag['token_rails_secret'],
    :token_devise_secret => encrypted_data_bag['token_devise_secret'],
    :token_devise_pepper => encrypted_data_bag['token_devise_pepper']
  })
end

# git

apt_repository 'git' do
  uri          'http://ppa.launchpad.net/git-core/ppa/ubuntu'
  distribution node[:lsb][:codename]
  components   %w[main]
  keyserver    'keyserver.ubuntu.com'
  key          'E1DF1F24'
  action       :add
end

include_recipe 'git'

repo_path = "/home/#{node[:app_name][:base][:username]}/#{cookbook_name}.git"

directory repo_path do
  owner node[:app_name][:base][:username]
  group node[:app_name][:base][:username]
  mode 0755
end

execute 'initialize new bare git repo' do
  user node[:app_name][:base][:username]
  group node[:app_name][:base][:username]
  command "cd #{repo_path} && git init --bare"
  not_if { File.exists? "#{repo_path}/HEAD" }
end

# imagemagick

package 'imagemagick'

# node

node.override[:nodejs][:install_method] = 'binary'
node.override[:nodejs][:version] = '0.10.24'
node.override[:nodejs][:checksum] = 'fb6487e72d953451d55e28319c446151c1812ed21919168b82ab1664088ecf46'
node.override[:nodejs][:checksum_linux_x64] = '423018f6a60b18d0dddf3007c325e0cc8cf55099'
node.override[:nodejs][:checksum_linux_x86] = 'fb6487e72d953451d55e28319c446151c1812ed21919168b82ab1664088ecf46'
include_recipe 'nodejs::install_from_binary'

# ruby

node.override[:rvm][:default_ruby] = node[:app_name][:service][:ruby_version]
node.override[:rvm][:global_gems] = [ { 'name' => 'bundler', 'version' => '1.5.1' } ]
node.override[:rvm][:group_users] = [ node[:app_name][:base][:username] ]

include_recipe 'rvm::system'

# service

deploy_path = "/home/#{node[:app_name][:base][:username]}/#{cookbook_name}"
shared_path = "#{deploy_path}/shared"

env_hash = SourceEnvironment.from_etc_profile(cookbook_name)
rvm_context = "/usr/local/rvm/bin/rvm #{node[:app_name][:service][:ruby_version]} do"

create_paths = %W(#{deploy_path} #{shared_path} #{shared_path}/vendor #{shared_path}/vendor/bundle #{shared_path}/log #{shared_path}/tmp #{shared_path}/public #{shared_path}/public/assets #{shared_path}/public/system)

create_paths.each do |path|
  directory path do
    owner node[:app_name][:base][:username]
    group node[:app_name][:base][:username]
    mode 0755
    action :create
    not_if { Dir.exists? path }
  end
end

deploy_revision deploy_path do
  user node[:app_name][:base][:username]
  repo repo_path
  revision 'HEAD'
  migrate true
  migration_command "#{rvm_context} bundle exec rake db:migrate"
  environment env_hash
  keep_releases 3
  action node[:app_name][:service][:deploy_action]
  restart_command 'touch /tmp/todo'
  symlink_before_migrate.clear
  purge_before_symlink %w(log tmp public/assets public/system)
  create_dirs_before_symlink []
  symlinks(
    'log'           => 'log',             # current/log           -> shared/log
    'tmp'           => 'tmp',             # current/tmp           -> shared/tmp
    'public/assets' => 'public/assets',   # current/public/assets -> shared/public/assets
    'public/system' => 'public/system'    # current/public/system -> shared/public/system
  )

  before_migrate do
    bundle_path = 'vendor/bundle'

    link "#{release_path}/#{bundle_path}" do
      to "#{shared_path}/#{bundle_path}"
    end

    bundle_without = %w(development test cucumber staging production)
    bundle_without -= [node[:app_name][:service][:environment]]
    bundle_command = "bundle install --path=#{bundle_path} --without #{bundle_without.join(' ')}"
    bundle_command += ' --deployment' if File.join(release_path, 'Gemfile.lock')

    

    execute "#{rvm_context} #{bundle_command}" do
      cwd release_path
      user node[:app_name][:base][:username]
      environment env_hash
    end

    execute "#{rvm_context} bundle exec rake db:create db:seed" do
      cwd release_path
      user node[:app_name][:base][:username]
      environment env_hash
    end
  end

  before_symlink do
    %W(#{release_path}/public/assets #{release_path}/public/system).each do |path|
      directory path do
        owner node[:app_name][:base][:username]
        group node[:app_name][:base][:username]
        mode 0755
        action :create
        not_if { Dir.exists? path }
      end
    end
  end

  before_restart do
    execute "#{rvm_context} bundle exec rake assets:precompile" do
      cwd release_path
      user node[:app_name][:base][:username]
      environment env_hash
    end
  end
end
CODE
end

gsub_file 'recipes/service.rb', 'app_name', app_name

git add: '.'
git commit: "-m 'Add the service recipe'"

# ----- Create default recipe -------------------------------------------------------------------------

puts
say_status  'recipes', 'Creating default recipe...', :yellow
puts        '-'*80, ''; sleep 0.25

run 'rm -f recipes/default.rb'
file 'recipes/default.rb' do <<-CODE
include_recipe '#{app_name}::database'
include_recipe '#{app_name}::cache'
include_recipe '#{app_name}::web'
include_recipe '#{app_name}::service'
include_recipe '#{app_name}::worker'
CODE
end

git add: '.'
git commit: "-m 'Add the default recipe'"

# ----- Installation complete message -----------------------------------------------------------------

puts
say_status  'success', "\e[1m\Everything has been setup successfully\e[0m", :cyan
puts
say_status  'question', 'Are you new to chef and berkshelf?', :yellow
say_status  'answer', 'Check the orats wiki for the walk through', :white
puts
say_status  'question', 'Are you somewhat experienced with chef?', :yellow
say_status  'answer', 'Setup your encrypted data bag and bootstrap the node', :white
puts        '-'*80