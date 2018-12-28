#
# Cookbook Name:: demoenv
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

# SSH keys
users = data_bag_item('support-ssh-keys', 'users')
users.delete('id')

users.each do |name, ssh_key|
  ssh_authorize_key name do
    key ssh_key['key']
    user ssh_key['user']
  end
end

# Set node hostname
include_recipe "system::hostname"

# Configure chef-client
include_recipe "chef-client"
include_recipe "chef-client::config"

# Perform demo env tunning
monolithic = search(:node, "role:demo-monolithic AND environment:#{node['demoenv']['environment']}")
unless node['abiquo']['profile'] == "monitoring"
  include_recipe "demoenv::#{node['abiquo']['profile']}"
else
  if monolithic.count > 0
    node.set['abiquo']['monitoring']['rabbitmq']['host'] = monolithic.first['ipaddress']
    include_recipe "demoenv::#{node['abiquo']['profile']}"
  end
end
