#
# Cookbook Name:: demoenv
# Recipe:: nfs
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

# Setup NFS server
include_recipe "nfs"

# Ensure NFS will survive restarts
service "nfs" do
  action :enable
end

# Crate dirs to be shared
%w(sharedds-1 sharedds-2).each do |dsname|
  directory "/nfs/#{dsname}" do
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
    action :create
  end
end

directory '/nfs/storage-pool' do
  owner 'root'
  group 'root'
  mode '0755'
  recursive true
  action :create
end

# Search for KVM hosts and save them to an attribute so we can query from KVMs
kvm_hosts = search(:node, "role:demo-kvm AND environment:#{node['demoenv']['environment']}")
if kvm_hosts.count > 0 
  # There are KVM hosts in the env!
  ips = kvm_hosts.map {|k| k['ipaddress'] }.join(",")
  node.set['demoenv']['kvm_hosts'] = ips
end

# If we know about KVM hosts, setup NFS export
if node['demoenv']['kvm_hosts']
  ips = node['demoenv']['kvm_hosts'].split(",")

  ips.each do |ip|
    %w(sharedds-1 sharedds-2).each do |dsname|
      nfs_export "/nfs/#{dsname}" do
        network ip
        writeable true
        sync true
        options ['no_root_squash', 'no_subtree_check']
        notifies :restart, "service[nfs]"
      end
    end

    nfs_export '/nfs/storage-pool' do
      network ip
      writeable true
      sync true
      options ['no_root_squash', 'no_subtree_check']
      notifies :restart, "service[nfs]"
    end
  end
end