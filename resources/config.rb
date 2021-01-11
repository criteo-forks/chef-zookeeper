#
# Cookbook:: zookeeper
# Resource:: config
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

# The original filename supplied with ZK is called 'zoo.cfg'
property :conf_file,         String, name_property: true
property :conf_dir,          String, default: '/opt/zookeeper/conf'
property :nodes,             Hash, default: {}
property :config,            Hash, default: { 'clientPort' => 2181,
                                              'dataDir' => '/var/lib/zookeeper',
                                              'tickTime' => 2000,
                                              'initLimit' => 5,
                                              'syncLimit' => 2 }
property :log_dir,           String, default: '/var/log/zookeeper'
# See zookeeper config files (conf/zkEnv.sh, etc.) for more options
property :env_vars,          Hash, default: {}
property :user,              String, default: 'zookeeper'
property :java_opts,         String, default: "-Xmx#{(node['memory']['total'].to_i * 0.8).floor / 1024}m"

include Zk::Gem

action :create do
  directory new_resource.conf_dir do
    owner     new_resource.user
    group     new_resource.user
    recursive true
  end
  static_conf = "#{new_resource.conf_dir}/#{new_resource.conf_file}"
  conf = new_resource.config.dup
  unless has_dynamic_config?(new_resource.nodes, static_conf)
    conf.merge!(new_resource.nodes)
  end

  file static_conf do
    owner   new_resource.user
    group   new_resource.user
    content lazy do
      new_conf = Zk::ZookeeperConfig.from_h(conf)
      old_conf = if File.exist?(static_conf)
                   Zk::ZookeeperConfig.from_text(File.read(static_conf))
                 else
                   Zk::ZookeeperConfig.new()
                 end
      old_conf.apply!(new_conf).to_s
    end
  end

  # Ensure that, even if an attribute is passed in, we can
  # operate on it without running into read-only issues
  env_vars_hash = new_resource.env_vars.to_hash.dup
  env_vars_hash['ZOOCFGDIR']   = new_resource.conf_dir
  env_vars_hash['ZOOCFG']      = new_resource.conf_file
  env_vars_hash['ZOO_LOG_DIR'] = new_resource.log_dir
  env_vars_hash['JVMFLAGS']    = new_resource.java_opts if new_resource.java_opts

  file "#{new_resource.conf_dir}/zookeeper-env.sh" do
    owner   new_resource.user
    group   new_resource.user
    content exports_config(env_vars_hash) + "\n"
  end
end

action :delete do
  Chef::Log.info "Deleting Zookeeper config at #{path}"

  [
    new_resource.conf_file,
    'zookeeper-env.sh',
  ].each do |f|
    file "#{new_resource.conf_dir}/#{f}" do
      action :delete
    end
  end
end
