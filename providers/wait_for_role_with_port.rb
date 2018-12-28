#
# Cookbook Name:: wordpressdemo
# Recipe:: frontend
#
# Copyright (c) 2015 The Authors, All Rights Reserved.
#
# Helpers to wait for services
#

def whyrun_supported?
  true
end

action :wait do
  converge_by("Waiting for role with port enabled") do
    available = false
    begin
      Chef::Log.info "Waiting until #{new_resource.name} is available..."
      Timeout::timeout(new_resource.timeout) do
        begin
          if search(:node, "role:#{new_resource.name}").first
            Chef::Log.info "GREPME found this #{search(:node, "role:#{new_resource.name}")}"
            available = true if ! search(:node, "role:#{new_resource.name}").first['ipaddress'].empty?
            break
          end
        end
       end
      Chef::Log.info "Waiting #{new_resource.delay} seconds before retrying..."
      sleep(new_resource.delay) if not available
    end until available

    Chef::Log.info "GREPME"
    Chef::Log.info "ROLE #{new_resource.name} available"

    available = false
    begin
      Chef::Log.info "Waiting until #{new_resource.name} - #{new_resource.port} is available..."
      host = search(:node, "role:#{new_resource.name}").first['ipaddress']
      Timeout::timeout(new_resource.timeout) do
        begin
          TCPSocket.new(host, new_resource.port).close
          available = true
          break
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Timeout::Error
          available = false
        end
       end
      Chef::Log.info "Waiting #{new_resource.delay} seconds before retrying..."
      sleep(new_resource.delay) if not available
    end until available
    
    new_resource.updated_by_last_action(true)
  end
end