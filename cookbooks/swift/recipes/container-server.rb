#
# Cookbook Name:: swift
# Recipe:: swift-container-server
#
# Copyright 2012, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "swift::common"
include_recipe "swift::storage-common"
include_recipe "swift::disks"

platform_options = node["swift"]["platform"]

platform_options["container_packages"].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options["override_options"]
  end
end

# epel/f-17 missing init scripts for the non-major services.
# https://bugzilla.redhat.com/show_bug.cgi?id=807170
%w{auditor updater replicator}.each do |svc|
  template "/etc/systemd/system/openstack-swift-container-#{svc}.service" do
    owner "root"
    group "root"
    mode "0644"
    source "simple-systemd-config.erb"
    variables({ :description => "OpenStack Object Storage (swift) - " +
                "Container #{svc.capitalize}",
                :user => "swift",
                :exec => "/usr/bin/swift-container-#{svc} " +
                "/etc/swift/container-server.conf"
              })
    only_if { platform?(%w{fedora}) }
  end
end

%w{swift-container swift-container-auditor swift-container-replicator swift-container-updater}.each do |svc|
  service_name=platform_options["service_prefix"] + svc + platform_options["service_suffix"]

  service svc do
    service_name = service_name
    provider platform_options["service_provider"]
    supports :status => true, :restart => true
    action [:enable, :start]
    only_if "[ -e /etc/swift/container-server.conf ] && [ -e /etc/swift/container.ring.gz ]"
  end

  monitoring_procmon svc do
    process_name "python.*#{svc}"
    start_cmd "/usr/sbin/service #{service_name} start"
    stop_cmd "/usr/sbin/service #{service_name} stop"
    only_if "[ -e /etc/swift/container-server.conf ] && [ -e /etc/swift/container.ring.gz ]"
  end
end

container_endpoint = get_bind_endpoint("swift","container-server")

template "/etc/swift/container-server.conf" do
  source "container-server.conf.erb"
  owner "swift"
  group "swift"
  mode "0600"
  variables("bind_ip" => container_endpoint["host"],
            "bind_port" => container_endpoint["port"])

  notifies :restart, "service[swift-container]", :immediately
  notifies :restart, "service[swift-container-replicator]", :immediately
  notifies :restart, "service[swift-container-updater]", :immediately
  notifies :restart, "service[swift-container-auditor]", :immediately
end
