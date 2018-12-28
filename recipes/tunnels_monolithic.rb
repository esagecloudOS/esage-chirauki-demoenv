#
# Cookbook Name:: demoenv
# Recipe:: tunnels_monolithic
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

%w(8021q l2tp_core l2tp_netlink l2tp_eth).each do |mod|
  kernel_module mod do
    onboot true
    action :load
  end
end

node['demoenv']['tunnel_info'].keys.each do |kvm_ip|
  tunnel_info = node['demoenv']['tunnel_info'][kvm_ip]

  execute "create-tunnel-with-#{kvm_ip}" do
    command "ip l2tp add tunnel tunnel_id #{tunnel_info['tunnel_id']} peer_tunnel_id #{tunnel_info['tunnel_id']} \
              encap udp local #{node['ipaddress']} remote #{kvm_ip} udp_sport #{tunnel_info['port']} udp_dport #{tunnel_info['port']}"
    action :run
    not_if "ip l2tp show tunnel | grep \"Tunnel #{tunnel_info['tunnel_id']}\""
  end

  execute "create-tunnel-session-with-#{kvm_ip}" do
    command "ip l2tp add session tunnel_id #{tunnel_info['tunnel_id']} session_id #{tunnel_info['tunnel_id']} peer_session_id #{tunnel_info['tunnel_id']}"
    action :run
    not_if "ip l2tp show session | grep \"Session #{tunnel_info['tunnel_id']} in tunnel #{tunnel_info['tunnel_id']}\""
  end

  ifindex = tunnel_info['tunnel_id'] - 1
  execute "set-link-mtu" do
    command "ip link set dev l2tpeth#{ifindex} mtu 1500"
    action :run
    not_if "ip link show dev l2tpeth#{ifindex} | grep \"mtu 1500\""
    notifies :restart, 'service[dhcpd]'
  end

  execute "set-link-up" do
    command "ip link set dev l2tpeth#{ifindex} up"
    action :run
    not_if "ip link show dev l2tpeth#{ifindex} | grep \"state UP\""
    notifies :restart, 'service[dhcpd]'
  end
end

# Create VLAN bridge
execute 'create-brvlan-bridge' do
  command "ip link add name brvlan type bridge"
  action :run
  not_if "ip link show dev brvlan"
  notifies :restart, 'service[dhcpd]'
end

execute 'bring-brvlan-up' do
  command "ip link set dev brvlan up"
  action :nothing
  subscribes :run, 'execute[create-brvlan-bridge]', :immediately
end

# Add L2TP int to bridge
node['demoenv']['tunnel_info'].keys.each do |kvm_ip|
  ifindex = node['demoenv']['tunnel_info'][kvm_ip]['tunnel_id'] - 1

  execute "add-l2tpeth#{ifindex}-to-brvlan" do
    command "ip link set l2tpeth#{ifindex} master brvlan"
    action :nothing
    subscribes :run, 'execute[create-brvlan-bridge]', :immediately
  end
end

# VLAN interfaces
(10..20).each do |tag|
  # Create the vlan int
  execute "create-vlan-int-brvlan.#{tag}" do
    command "ip link add link brvlan name brvlan.#{tag} type vlan id #{tag}"
    action :run
    not_if "ip link show dev brvlan.#{tag}"
  end

  # Give it and IP so dhcpd responds on it
  execute "set-ip-brvlan.#{tag}" do
    command "ip addr add #{tag}.#{tag}.#{tag}.#{tag}/24 dev brvlan.#{tag}"
    action :nothing
    subscribes :run, "execute[create-vlan-int-brvlan.#{tag}]", :immediately
  end

  # Bring the int up
  execute "set-link-brvlan.#{tag}-up" do
    command "ip link set dev brvlan.#{tag} up"
    action :nothing
    subscribes :run, "execute[set-ip-brvlan.#{tag}]", :immediately
    notifies :restart, 'service[dhcpd]'
  end
end

# Firewall
include_recipe "iptables"
iptables_rule "firewall-tunnels"
