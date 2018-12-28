#
# Cookbook Name:: demoenv
# Recipe:: monolithic
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

node.set['mariadb']['replication']['server_id'] = '2'
node.set['mariadb']['replication']['options'] = {
  'log_bin' => '# Disable log_bin',
  'replicate-ignore-db' => 'mysql'
}

# Find Out monolithic IP
monolithics = search(:node, "role:demo-monolithic AND environment:#{node['demoenv']['environment']}")

if monolithics.count > 0
  # There should be only 1 monolithic right?
  monolithic = monolithics.first
  
  # Get the IP for the NFS mount
  monolithic_ip = monolithic['ipaddress']
  node.set['abiquo-reporting']['db']['slave-of'] = monolithic_ip

  include_recipe 'abiquo-reporting::default'
end
