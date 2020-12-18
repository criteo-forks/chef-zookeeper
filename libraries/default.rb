# libraries/default.rb

module Zk
  PERM_NONE   = 0x00
  PERM_READ   = 0x01
  PERM_WRITE  = 0x02
  PERM_CREATE = 0x04
  PERM_DELETE = 0x08
  PERM_ADMIN  = 0x10
  PERM_ALL    = PERM_READ | PERM_WRITE | PERM_CREATE | PERM_DELETE | PERM_ADMIN

  def self.error_message(error_code)
    case error_code
    when -1 then 'System error'
    when -2 then 'Runtime inconsistency'
    when -3 then 'Data inconsistency'
    when -4 then 'Connection loss'
    when -5 then 'Marshalling error'
    when -6 then 'Unimplemented'
    when -7 then 'Operation timeout'
    when -8 then 'Bad arguments'
    when -13 then 'New config no Quorum'
    when -14 then 'Another reconfiguration is in progress'
    when -100 then 'Api errors'
    when -101 then 'Node does not exists'
    when -102 then 'No authentication'
    when -103 then 'Bad version'
    when -108 then 'No children for ephemerals'
    when -110 then 'Node already exists'
    when -111 then 'Node not empty'
    when -112 then 'Session has expired'
    when -113 then 'Invalid callback'
    when -114 then 'Invalid acl'
    when -115 then 'Authentication has failed'
    when -118 then 'Session has moved'
    when -119 then 'This server does not support read only'
    when -120 then 'Attempt to create ephemeral node on a local session'
    when -121 then 'Attempts to remove a non-existing watcher'
    else 'Unknown'
    end
  end

  module Gem
    def zk
      require 'zookeeper'
      # use class variable otherwise new connection is created for each resource
      @@zk ||= ::Zookeeper.new(connect_str).tap do |zk|
        zk.add_auth scheme: auth_scheme, cert: auth_cert unless auth_cert.nil?
      end
    end

    def has_dynamic_config?(nodes, conf_file)
      return false if nodes.size <= 1

      File.readlines(conf_file).any? do |line|
        line =~ /dynamicConfigFile/
      end
    end

    def dynamic_config_version(conf_file)
      File.readlines(conf_file).select do |line|
        line =~ /dynamicConfigFile/
      end[0].split('=')[1].strip
    end

    def dynamic_config!(c)
      require 'mixlib/shellout'
      # FIXME(t.lange): zk gem will hopefully export the reconfig command one day
      authstr = ''
      authstr = "addauth #{auth_scheme} #{auth_cert}\n" unless auth_cert.nil?
      Mixlib::ShellOut.new("echo -e \"#{authstr}reconfig -members #{c}\" | /opt/zookeeper/bin/zkCli.sh").run_command.error!
    end

    def compile_acls
      require 'zookeeper'

      @compiled_acls ||= [].tap do |acls|
        acls << ::Zookeeper::ACLs::ACL.new(id: { id: 'anyone', scheme: 'world' }, perms: acl_world)

        %w(digest ip sasl).each do |scheme|
          send("acl_#{scheme}".to_sym).each do |id, perms|
            acls << ::Zookeeper::ACLs::ACL.new(id: { scheme: scheme, id: id }, perms: perms)
          end
        end
      end
    end
  end
end
