#
# Cookbook Name:: collectd
# Recipe:: default
#
# Copyright 2010, Atari, Inc
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

package "collectd" do
  case node['platform']
    when "ubuntu"
      package_name "collectd-core"
    when "fedora"
      package_name "collectd"
  end
end

service "collectd" do
  supports :restart => true, :status => true
end

directory "/etc/collectd" do
  owner "root"
  group "root"
  mode "755"
end

directory "/etc/collectd/plugins" do
  owner "root"
  group "root"
  mode "755"
end

directory "/etc/collectd/thresholds" do
  owner "root"
  group "root"
  mode "755"
end

directory node['collectd']['base_dir'] do
  owner "root"
  group "root"
  mode "755"
  recursive true
end

directory node['collectd']['plugin_dir'] do
  owner "root"
  group "root"
  mode "755"
  recursive true
end

%w(collectd collection thresholds).each do |file|
  template "/etc/collectd/#{file}.conf" do
    source "#{file}.conf.erb"
    owner "root"
    group "root"
    mode "644"
    notifies :restart, resources(:service => "collectd")
  end
end

Chef::Log.error("Running old plugin deleterator")

old_configs = node["monitoring"]["configs"] || []
node["monitoring"]["configs"] = []

Dir['/etc/collectd/plugins/*.conf'] +
  Dir['/etc/collectd/thresholds/*.conf'].each do |path|

  autogen = false
  File.open(path).each_line do |line|
    if line.start_with?('#') and line.include?('autogenerated')
      autogen = true
      break
    end
  end
  if autogen
    if not old_configs.include?(path)
      Chef::Log.info("Deleting old config in #{path}")
      File.unlink(path)
    end
  end
end

service "collectd" do
  action [:enable, :start]
end
