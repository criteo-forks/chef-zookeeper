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
  return unless has_dynamic_config?(new_resource.nodes, new_resource.static_conf)

  conf = new_resource.nodes.map do |k, v|
    "#{k}=#{v}"
  end.join(';2181,') + ';2181'
  dynamic_config!(conf)
end

action :delete do
end
