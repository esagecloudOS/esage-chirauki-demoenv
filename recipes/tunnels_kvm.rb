#
# Cookbook Name:: demoenv
# Recipe:: tunnels_kvm
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

# Find out tunnel_info
my_tunnel = {}
monolithic_ip = nil
monolithics = search(:node, "role:demo-monolithic AND environment:#{node['demoenv']['environment']}")
if monolithics.count > 0
  # There should be only 1 monolithic right?
  monolithic = monolithics.first

  # Find out my tunnel info
  my_tunnel = monolithic['demoenv']['tunnel_info'][node['ipaddress']].clone unless monolithic['demoenv']['tunnel_info'].nil?
  node.set['demoenv']['my_tunnel'] = my_tunnel
end

if my_tunnel.empty?
  Chef::Log.info "No data to setup tunnel. Skipping."
else
  monolithic_ip = my_tunnel['monolithic']
  execute "create-tunnel-with-#{monolithic_ip}" do
    command "ip l2tp add tunnel tunnel_id #{my_tunnel['tunnel_id']} peer_tunnel_id #{my_tunnel['tunnel_id']} \
              encap udp local #{node['ipaddress']} remote #{monolithic_ip} udp_sport #{my_tunnel['port']} udp_dport #{my_tunnel['port']}"
    action :run
    not_if "ip l2tp show tunnel | grep \"Tunnel #{my_tunnel['tunnel_id']}\""
  end

  execute "create-tunnel-session-with-#{monolithic_ip}" do
    command "ip l2tp add session tunnel_id #{my_tunnel['tunnel_id']} session_id #{my_tunnel['tunnel_id']} peer_session_id #{my_tunnel['tunnel_id']}"
    action :run
    not_if "ip l2tp show session | grep \"Session #{my_tunnel['tunnel_id']} in tunnel #{my_tunnel['tunnel_id']}\""
  end

  execute "set-link-mtu" do
    command "ip link set dev l2tpeth0 mtu 1500"
    action :run
    not_if "ip link show dev l2tpeth0 | grep \"mtu 1500\""
  end

  execute "set-link-up" do
    command "ip link set dev l2tpeth0 up"
    action :run
    not_if "ip link show dev l2tpeth0 | grep \"state UP\""
  end
end

# Firewall
include_recipe "iptables"
iptables_rule "firewall-tunnels"
