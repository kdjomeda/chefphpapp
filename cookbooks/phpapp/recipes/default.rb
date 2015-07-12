# Cookbook Name:: phpapp
# Recipe:: default
#
# Copyright 2015, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'apache2'
include_recipe 'apache2::mod_actions'
include_recipe 'php-fpm::default'
include_recipe 'mysql::client'
include_recipe 'mysql::server'
include_recipe 'mysql::ruby'
include_recipe 'mysql2_chef_gem'


cookbook_file "Installing multiverse repository" do
 path "/etc/apt/sources.list.d/multiverse.list"
 source "multiverse"
 owner "root"
 group "root"
 mode "0644"
 action :create
 notifies :run, 'execute[apt-get update]', :immediately
end

package "libapache2-mod-fastcgi"

#web_app 'phpapp' do
#  template 'site.conf.erb'
#  docroot node['phpapp']['path']
#  server_name node['phpapp']['server_name']
#end

service 'apache2' do
	supports :status => true
	action [:enable, :start]
end

user node["phpapp"]["user_name"] do
  comment 'system user for phpapp application'
  system true
  shell '/bin/false'
end

directory node["phpapp"]["path"] do
  owner "#{node["phpapp"]["user_name"]}"
  group "#{node["phpapp"]["user_name"]}"
  mode "0755"
  action :create
  recursive true
end

cookbook_file "/etc/apache2/conf-available/php5-fpm.conf" do
  source "php5-fpm"
  group "root"
  owner "root"
  mode "0644"
  action :create
  #notifies :run, 'execute[reload-apache-config]', :immediately
end

#execute 'reload-apache-config' do
# command 'a2enconf php5-fpm.conf'
#end

template "/etc/php5/fpm/pool.d/#{node['phpapp']['user_name']}.conf" do 
  source 'php-fpm-pool.erb' 
  mode '0644'
  owner 'root'
  group	'root'
  variables({
  	:user_name => node['phpapp']['user_name']
  })
end

file "#{node['phpapp']['path']}/test.php" do
  content "<?php echo phpinfo(); ?>"
  owner "#{node['phpapp']['user_name']}"
  group "#{node['phpapp']['user_name']}"
  mode "755"
end

directory "/var/log/apache2/#{node['phpapp']['server_name']}" do
  owner "#{node['phpapp']['user_name']}"
  group "#{node['phpapp']['user_name']}"
  mode "0755"
  recursive true
end
 
web_app 'phpapp' do
  template 'site-fpm.conf.erb'
  docroot node['phpapp']['path']
  server_name node['phpapp']['server_name']
  user_name node['phpapp']['user_name']
end


package 'php5-mysql'

mysql_database node['phpapp']['database'] do
  connection ({:host => 'localhost',:username => 'root', :password => node['mysql']['server_root_password']})
  action :create
end

mysql_database_user node['phpapp']['db_username'] do
  connection ({:host => 'localhost',:username => 'root', :password => node['mysql']['server_root_password']})
  password node['phpapp']['db_password']
  database_name node['phpapp']['database']
  privileges [:select,:update,:insert,:create,:delete]
  action :grant
end

wordpress_latest = Chef::Config[:file_cache_path] + "/wordpress-latest.tar.gz"

remote_file wordpress_latest do
  source "https://wordpress.org/latest.tar.gz"
  mode "0644"
end

execute "untar-wordpress" do
  cwd node['phpapp']['path']
  command "tar --strip-components 1 -xzf " + wordpress_latest
  creates node['phpapp']['path'] + "/wp-settings.php"
end

wp_secrets = Chef::Config[:file_cache_path] + '/wp-secrets.php'

if File.exist?(wp_secrets)
  salt_data = File.read(wp_secrets)
else
  require 'open-uri'
  salt_data = open('https://api.wordpress.org/secret-key/1.1/salt/').read
  open(wp_secrets, 'wb') do |file|
    file << salt_data
  end
end

template node['phpapp']['path'] + '/wp-config.php' do
  source 'wp-config.php.erb'
  mode 0755
  owner 'root'
  group 'root' 
  variables(
    :database        => node['phpapp']['database'],
    :user            => node['phpapp']['db_username'],
    :password        => node['phpapp']['db_password'],
    :wp_secrets      => salt_data)
end
