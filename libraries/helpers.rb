#
# Cookbook Name:: demoenv
# Library:: helpers
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

require 'chef/platform'

module Demoenv
  module Checks
    module API
      def can_download_templates(connection_data)
        begin
          abq = AbiquoAPI.new(connection_data)
        rescue Exception
          Chef::Log.info "We can't connect to Abiquo API. Not downloading."
          return false
        end

        # Check AM exists
        l = AbiquoAPI::Link.new(
          :href => '/api/admin/remoteservices',
          :type => 'application/vnd.abiquo.remoteservices+json',
          :client => abq
        )

        rss = l.get
        am = if rss.size > 0
          rss.select {|r| r.type == "APPLIANCE_MANAGER" }.first
        else
          nil
        end
        if am.nil?
          Chef::Log.info "AM does not exist. Not downloading."
          return false
        end

        # Check license
        l = AbiquoAPI::Link.new(
          :href => '/api/config/licenses',
          :type => 'application/vnd.abiquo.licenses+json',
          :client => abq
        )

        lics = l.get
        license = if lics.size > 0
          lics.first
        else
          nil
        end
        if license.nil?
          Chef::Log.info "License does not exist. Not downloading."
          return false
        end

        # Check KVMs
        dc = find_dc(node['demoenv']['datacenter_name'], abq)
        raise "Could not find DC '#{node['demoenv']['datacenter_name']}'" if dc.nil?
        rack = dc.link(:racks).get.select {|r| r.name == node['demoenv']['rack_name'] }.first
        raise "Could not find Rack '#{rack_name}'" if rack.nil?
        if rack.link(:machines).get.size == 2
          Chef::Log.info "Everything seems right! Downloading."
          return true
        else
          Chef::Log.info "Still waiting for some KVM. Not downloading."
          return false
        end
      end

      private

      def find_dc(dc_name, abq)
        l = AbiquoAPI::Link.new(
          :href => '/api/admin/datacenters',
          :type => 'application/vnd.abiquo.datacenters+json',
          :client => abq
        )

        dcs = l.get
        if dcs.size > 0
          dcs.select {|d| d.name.eql? dc_name }.first
        else
          nil
        end
      end
    end
  end
end
