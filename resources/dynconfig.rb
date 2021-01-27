#
# Cookbook:: zookeeper
# Resource:: dynconfig
#
# Copyright:: 2014, Simple Finance Technology Corp.
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

property :nodes,            Hash, default: {}
property :static_conf,      String, default: ''
property :auth_cert,   [String, nil], desired_state: false
property :auth_scheme, default: 'digest', desired_state: false
property :connect_str, String, required: true, desired_state: false

include Zk::Gem

action :create do
  # If there is no config file, it's unlikely zookeeper is running...
  return unless ::File.exist?(new_resource.static_conf)

  return unless has_dynamic_config?(new_resource.nodes, new_resource.static_conf)

  original = ZookeeperDynamicConfig.from_api(dynamic_config)
  target = ZookeeperDynamicConfig.from_h(new_resource.nodes)

  return if original == target

  converge_by('change dynamic configuration') do
    dynamic_config!(target.to_s)
  end
end

action :delete do
end
