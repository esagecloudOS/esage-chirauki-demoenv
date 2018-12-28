#
# Cookbook Name:: demoenv
# Recipe:: monolithic
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

Chef::Recipe.send(:include, Demoenv::Checks::API)

# Install Abiquo API gem
include_recipe "abiquo_api::default"

# Some default properties
node.set['abiquo']['properties']['abiquo.virtualfactory.kvm.fullVirt'] = false
node.set['abiquo']['properties']['abiquo.appliancemanager.repositoryLocation'] = "#{node['ipaddress']}:/opt/vm_repository"

# Find Out monitoring IP and setup properties
monitoring = search(:node, "role:demo-monitoring AND environment:#{node['demoenv']['environment']}")

if monitoring.count > 0
  monitoring_ip = monitoring.first['ipaddress']
  node.set['abiquo']['properties']['abiquo.monitoring.enabled'] = true
  node.set['abiquo']['properties']['abiquo.watchtower.host'] = monitoring_ip
  node.set['abiquo']['properties']['abiquo.watchtower.port'] = 36638
end

# Setup NFS server
include_recipe "nfs"

# Search for KVM hosts and save them to an attribute so we can query from KVMs
kvm_hosts = search(:node, "role:demo-kvm AND environment:#{node['demoenv']['environment']}")
if kvm_hosts.count > 0 
  # There are KVM hosts in the env!
  ips = kvm_hosts.map {|k| k['ipaddress'] }.join(",")
  node.set['demoenv']['kvm_hosts'] = ips

  # Tunnels
  tunnel_info = {}
  kvm_hosts.each_with_index do |kvm, i|
    tunnel_info[kvm['ipaddress']] = {
      'tunnel_id' => i + 1,
      'port' => 5000 + i,
      'monolithic' => node['ipaddress']
    }
  end
  node.set['demoenv']['tunnel_info'] = tunnel_info

  # Setup the tunnels
  include_recipe 'demoenv::tunnels_monolithic'
end

# Reporting
reportings = search(:node, "role:demo-reporting AND environment:#{node['demoenv']['environment']}")
if reportings.count > 0
  reporting_ip = reportings.first['ipaddress']

  node.set['abiquo']['ui_proxies']['/jasperserver'] = {
    'url' => "http://#{reporting_ip}:8888/jasperserver"
  }
end

# Firewall
include_recipe "iptables"
iptables_rule "firewall-nfs"

# Retrieve a demo license
ruby_block "obtain a demo license" do
  block do 
    require 'net/http'
    require 'json'

    uri = URI.parse(node['demoenv']['license_url'])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    param_hash = {
      "email" => "demo.#{node['demoenv']['environment']}@abiquo.com",
      "company" => node['demoenv']['environment'],
      "name" => "Abiquo Demo Env",
      "batch" => true
    }.to_json

    req = Net::HTTP::Post.new(uri.request_uri, {'Content-Type' =>'application/json'})
    req.body = param_hash
    response = http.request(req)

    node.set['demoenv']['license'] = response.body.gsub!("\n", "")
  end
  action :run
  only_if { node['demoenv']['license'].nil? || node['demoenv']['license'].empty? }
end

# MariaDB Listen address
node.set['mariadb']['mysqld']['bind_address'] = '0.0.0.0'

# Install Abiquo
include_recipe "abiquo::default"

# Replication user
conn_info = {
  host: '127.0.0.1',
  username: 'root',
  password: node['mariadb']['server_root_password'],
}

mysql_database_user "replication-user" do
  connection    conn_info
  username      node['demoenv']['replication_user']
  password      node['demoenv']['replication_password']
  host          '%'
  privileges    ['REPLICATION SLAVE']
  action        :grant
end

# If we know about KVM hosts, setup NFS export
if node['demoenv']['kvm_hosts']
  ips = node['demoenv']['kvm_hosts'].split(",")

  ips.each do |ip|
    nfs_export "/opt/vm_repository" do
      network ip
      writeable true
      sync true
      options ['no_root_squash', 'no_subtree_check']
      notifies :restart, "service[nfs]"
    end
  end
end

# Ensure NFS will survive restarts
service "nfs" do
  action :enable
end

# File required in order to use the vm_repository
directory '/opt/vm_repository' do
  owner 'tomcat'
  group 'root'
end

file '/opt/vm_repository/.abiquo_repository' do 
  content ''
  owner 'tomcat'
  group 'tomcat'
end

unless node['demoenv']['license'].nil?
  # Add license
  abiquo_api_license 'add-demo-license' do
    code node['demoenv']['license']
    abiquo_connection_data node['demoenv']['abiquo_connection_data']
    action :create
    # subscribes :create, "ruby_block[obtain a demo license]"
    only_if "while /bin/netstat -lnt | awk '$4 ~ /:8009$/ {exit 1}'; do /bin/sleep 2; done && /usr/bin/curl -u admin:xabiquo http://localhost:8009/api/version -H 'Accept: text/plain' -s > /dev/null"
    not_if { node['demoenv']['license'] == "" or node['demoenv']['license'].nil? }
  end
end

# Create datacenter
abiquo_api_datacenter node['demoenv']['datacenter_name'] do
  location "Somewhere over the rainbows"
  abiquo_connection_data node['demoenv']['abiquo_connection_data']
  action :create
  only_if "while /bin/netstat -lnt | awk '$4 ~ /:8009$/ {exit 1}'; do /bin/sleep 2; done && /usr/bin/curl -u admin:xabiquo http://localhost:8009/api/version -H 'Accept: text/plain' -s > /dev/null"
  notifies :create, "abiquo_api_rack[#{node['demoenv']['rack_name']}]", :immediately
  ignore_failure true
end

# Public Cloud Regions
# SSH keys
regions = data_bag_item('demo-env-pcr', 'regions')
regions.delete('id')

regions['regions'].each do |region|
  abiquo_api_public_cloud_region region['name'] do
    region region['region']
    cloud_provider region['provider']
    abiquo_connection_data node['demoenv']['abiquo_connection_data']
    action :create
    only_if "while /bin/netstat -lnt | awk '$4 ~ /:8009$/ {exit 1}'; do /bin/sleep 2; done && /usr/bin/curl -u admin:xabiquo http://localhost:8009/api/version -H 'Accept: text/plain' -s > /dev/null"
    ignore_failure true
  end
end

# Create rack
abiquo_api_rack node['demoenv']['rack_name'] do
  datacenter node['demoenv']['datacenter_name']
  abiquo_connection_data node['demoenv']['abiquo_connection_data']
  vlan_min 10
  vlan_max 20
  action :nothing
  ignore_failure true
end

# Create Remote Services
abiquo_api_remote_service "http://#{node['ipaddress']}:8009/vsm" do
  type "VIRTUAL_SYSTEM_MONITOR"
  datacenter [node['demoenv']['datacenter_name'], "DO ams2"]
  abiquo_connection_data node['demoenv']['abiquo_connection_data']
  action :create
  ignore_failure true
end

abiquo_api_remote_service "guacd://#{node['ipaddress']}:4822/" do
  type "REMOTE_ACCESS"
  datacenter [node['demoenv']['datacenter_name'], "DO ams2"]
  abiquo_connection_data node['demoenv']['abiquo_connection_data']
  action :create
  ignore_failure true
end

abiquo_api_remote_service "http://#{node['ipaddress']}:8009/nodecollector" do
  type "NODE_COLLECTOR"
  datacenter [node['demoenv']['datacenter_name'], "DO ams2"]
  abiquo_connection_data node['demoenv']['abiquo_connection_data']
  action :create
  ignore_failure true
end

abiquo_api_remote_service "http://#{node['ipaddress']}:8009/virtualfactory" do
  type "VIRTUAL_FACTORY"
  datacenter [node['demoenv']['datacenter_name'], "DO ams2"]
  abiquo_connection_data node['demoenv']['abiquo_connection_data']
  action :create
  ignore_failure true
end

abiquo_api_remote_service "http://#{node['ipaddress']}:8009/ssm" do
  type "STORAGE_SYSTEM_MONITOR"
  datacenter node['demoenv']['datacenter_name']
  abiquo_connection_data node['demoenv']['abiquo_connection_data']
  action :create
  ignore_failure true
end

abiquo_api_remote_service "https://#{node['demoenv']['environment']}.#{node['demoenv']['lab_domain']}:443/am" do
  type "APPLIANCE_MANAGER"
  uuid node['abiquo']['properties']['abiquo.datacenter.id']
  datacenter node['demoenv']['datacenter_name']
  abiquo_connection_data node['demoenv']['abiquo_connection_data']
  action :create
  ignore_failure true
end

abiquo_api_remote_service "http://#{node['ipaddress']}:8009/bpm-async" do
  type "BPM_SERVICE"
  uuid node['abiquo']['properties']['abiquo.datacenter.id']
  datacenter node['demoenv']['datacenter_name']
  abiquo_connection_data node['demoenv']['abiquo_connection_data']
  action :create
  ignore_failure true
end

abiquo_api_remote_service "omapi://#{node['ipaddress']}:7911/" do
  type "DHCP_SERVICE"
  datacenter node['demoenv']['datacenter_name']
  abiquo_connection_data node['demoenv']['abiquo_connection_data']
  action :create
  ignore_failure true
end

abiquo_api_remote_service "http://#{node['ipaddress']}:8009/cpp" do
  type "CLOUD_PROVIDER_PROXY"
  datacenter "DO ams2"
  abiquo_connection_data node['demoenv']['abiquo_connection_data']
  action :create
  ignore_failure true
end

# Download some templates
abiquo_api_remote_repository 'Repository 3.0' do
  url "https://abq-repo-test.s3.amazonaws.com/ovfindex.xml"
  abiquo_connection_data node['demoenv']['abiquo_connection_data']
  action :create
  only_if "while /bin/netstat -lnt | awk '$4 ~ /:8009$/ {exit 1}'; do /bin/sleep 2; done && /usr/bin/curl -u admin:xabiquo http://localhost:8009/api/version -H 'Accept: text/plain' -s > /dev/null"
  ignore_failure true
end

if can_download_templates(node['demoenv']['abiquo_connection_data'])
  abiquo_api_template_download 'yVM' do
    datacenter node['demoenv']['datacenter_name']
    remote_repository_url "https://abq-repo-test.s3.amazonaws.com/ovfindex.xml"
    abiquo_connection_data node['demoenv']['abiquo_connection_data']
    action :download
    only_if "while /bin/netstat -lnt | awk '$4 ~ /:8009$/ {exit 1}'; do /bin/sleep 2; done && /usr/bin/curl -u admin:xabiquo http://localhost:8009/api/version -H 'Accept: text/plain' -s > /dev/null"
    ignore_failure true
  end

  abiquo_api_template_download 'Alpine Linux' do
    datacenter node['demoenv']['datacenter_name']
    remote_repository_url "https://abq-repo-test.s3.amazonaws.com/ovfindex.xml"
    abiquo_connection_data node['demoenv']['abiquo_connection_data']
    action :download
    only_if "while /bin/netstat -lnt | awk '$4 ~ /:8009$/ {exit 1}'; do /bin/sleep 2; done && /usr/bin/curl -u admin:xabiquo http://localhost:8009/api/version -H 'Accept: text/plain' -s > /dev/null"
    ignore_failure true
  end

  abiquo_api_template_download 'Centos 7 x86_64' do
    datacenter node['demoenv']['datacenter_name']
    remote_repository_url "https://abq-repo-test.s3.amazonaws.com/ovfindex.xml"
    abiquo_connection_data node['demoenv']['abiquo_connection_data']
    action :download
    only_if "while /bin/netstat -lnt | awk '$4 ~ /:8009$/ {exit 1}'; do /bin/sleep 2; done && /usr/bin/curl -u admin:xabiquo http://localhost:8009/api/version -H 'Accept: text/plain' -s > /dev/null"
    ignore_failure true
  end

  abiquo_api_template_download 'Ubuntu 16.04 LTS x86_64' do
    datacenter node['demoenv']['datacenter_name']
    remote_repository_url "https://abq-repo-test.s3.amazonaws.com/ovfindex.xml"
    abiquo_connection_data node['demoenv']['abiquo_connection_data']
    action :download
    only_if "while /bin/netstat -lnt | awk '$4 ~ /:8009$/ {exit 1}'; do /bin/sleep 2; done && /usr/bin/curl -u admin:xabiquo http://localhost:8009/api/version -H 'Accept: text/plain' -s > /dev/null"
    ignore_failure true
  end

  abiquo_api_template_download 'pfSense CE 2.3.4' do
    datacenter node['demoenv']['datacenter_name']
    remote_repository_url "https://abq-repo-test.s3.amazonaws.com/ovfindex.xml"
    abiquo_connection_data node['demoenv']['abiquo_connection_data']
    action :download
    only_if "while /bin/netstat -lnt | awk '$4 ~ /:8009$/ {exit 1}'; do /bin/sleep 2; done && /usr/bin/curl -u admin:xabiquo http://localhost:8009/api/version -H 'Accept: text/plain' -s > /dev/null"
    ignore_failure true
  end

  abiquo_api_template_download 'openSUSE 42.2 x86_64' do
    datacenter node['demoenv']['datacenter_name']
    remote_repository_url "https://abq-repo-test.s3.amazonaws.com/ovfindex.xml"
    abiquo_connection_data node['demoenv']['abiquo_connection_data']
    action :download
    only_if "while /bin/netstat -lnt | awk '$4 ~ /:8009$/ {exit 1}'; do /bin/sleep 2; done && /usr/bin/curl -u admin:xabiquo http://localhost:8009/api/version -H 'Accept: text/plain' -s > /dev/null"
    ignore_failure true
  end
end

if reportings.count > 0
  abiquo_api_system_property 'client.main.billingUrl' do
    value "https://#{node['demoenv']['environment']}.#{node['demoenv']['lab_domain']}/jasperserver"
    abiquo_connection_data node['demoenv']['abiquo_connection_data']
    only_if "while /bin/netstat -lnt | awk '$4 ~ /:8009$/ {exit 1}'; do /bin/sleep 2; done && /usr/bin/curl -u admin:xabiquo http://localhost:8009/api/version -H 'Accept: text/plain' -s > /dev/null"
    ignore_failure true
  end
end

package 'dhcp'

file "/etc/dhcp/dhcpd.conf" do
  owner 'root'
  group 'root'
  mode 0755
  content lazy { ::File.open("/opt/abiquo/config/examples/dhcpd.conf").read }
  action :create
  notifies :restart, 'service[dhcpd]'
end

# Ensure DHCPd is present
service 'dhcpd' do
  action [:enable, :start]
end
