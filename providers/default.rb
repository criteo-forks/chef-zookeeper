# providers/default.rb
#
# Copyright 2014, Simple Finance Technology Corp.
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

def initialize(new_resource, run_context)
  super
end

# Install Zookeeper
action :install do
  chef_gem 'zookeeper' do
    compile_time true
  end

  chef_gem 'json' do
    compile_time true
  end

  group new_resource.user

  user new_resource.user do
    gid new_resource.user
  end

  remote_file "zookeeper-#{new_resource.version}" do
    path ::File.join(Chef::Config[:file_cache_path], "zookeeper-#{new_resource.version}.tar.gz")
    owner 'root'
    mode 00644
    source lazy { ::File.join(new_resource.mirror, "zookeeper-#{new_resource.version}", "zookeeper-#{new_resource.version}.tar.gz") }
    checksum new_resource.checksum
  end

  directory new_resource.install_dir do
    owner new_resource.user
    group new_resource.user
    recursive true
    mode 00700
  end

  directory new_resource.data_dir do
    owner new_resource.user
    group new_resource.user
    recursive true
    mode 00700
  end

  unless ::File.exist?(::File.join(new_resource.install_dir, "zookeeper-#{new_resource.version}", "zookeeper-#{new_resource.version}.jar"))
    Chef::Log.info("Zookeeper version #{new_resource.version} not installed. Installing now!")
    execute 'install zookeeper' do
      cwd Chef::Config[:file_cache_path]
      command <<-EOS
tar -C #{new_resource.install_dir} -zxf zookeeper-#{new_resource.version}.tar.gz
chown -R #{new_resource.user}:#{new_resource.user} #{new_resource.install_dir}
      EOS
    end
  end
end

action :uninstall do
  Chef::Log.error("Unimplemented method :uninstall for resource `zookeeper'")
end
