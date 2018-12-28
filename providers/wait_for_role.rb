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
  converge_by("Waiting for #{new_resource.name}") do
    available = false
    begin
      Chef::Log.info "Waiting until #{new_resource.name} is available..."
      Timeout::timeout(new_resource.timeout) do
        begin
          available = true if search(:node, "role:#{new_resource.name}")
          break
        end
       end
      Chef::Log.info "Waiting #{new_resource.delay} seconds before retrying..."
      sleep(new_resource.delay) if not available
    end until available
    new_resource.updated_by_last_action(true)
  end
end