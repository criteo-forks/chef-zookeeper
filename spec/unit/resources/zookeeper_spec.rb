require 'spec_helper'
require_relative '../../../libraries/default'

describe 'zookeeper' do
  step_into :zookeeper
  platform 'ubuntu'

  context 'with default properties' do
    automatic_attributes['memory']['total'] = 2048

    recipe do
      zookeeper 'zookeeper' do
        use_java_cookbook false
      end
    end

    it { is_expected.to install_ark('zookeeper') }
  end
end

RSpec.describe Zk::ZookeeperConfig do
  describe '#from_h' do
    let(:hash_config) do
      { 'itemA' => 'valueA', 'itemB' => 'valueB' }
    end
    it 'generates a valid object' do
      subject = Zk::ZookeeperConfig.from_h(hash_config)
      expect(subject).not_to eq nil
    end
  end

  describe '#from_file' do
    let(:file_config) do
      "itemA=valueA\nitemB=valueB\n"
    end
    it 'generates a valid object' do
      subject = Zk::ZookeeperConfig.from_text(file_config)
      expect(subject).not_to eq nil
    end
    it 'exports exactly like the input' do
      subject = Zk::ZookeeperConfig.from_text(file_config)
      expect(subject.to_s).to eq(file_config)
    end
  end

  # This test validate the whole chain:
  # * original config is loaded from File (plain text)
  # * update config is loader from Chef hash
  # * update is applied to original config
  # Expected output:
  # * deleted fields disappear (excepted immutable ones)
  # * new fields are added at the bottom of the file
  # * unchanged/updated fields are at same position
  # * unforces a new line at the bottom of the config
  describe '#from_text#apply#to_s' do
    let(:existing_text_config) do
      text = <<~ORIG_FILE
      clientPort=2181
      dataDir=/var/lib/zookeeper
      tickTime=2000
      initLimit=5
      syncLimit=2
      maxClientCnxns=2048
      4lw.commands.whitelist=conf,isro,mntr,ruok,stat
      admin.enableServer=false
      tcpKeepAlive=true
      reconfigEnabled=true
      cnxTimeout=3
      dynamicConfigFile=/opt/zookeeper-3.5.8/conf/zoo.cfg.dynamic.2060000086c
      ORIG_FILE
      text.strip
    end
    let(:updated_hash_config) do
      {
        'cnxTimeout' => 5,
        'reconfigEnabled' => true,
        'tcpKeepAlive' => true,
        'admin.enableServer' => true,
        'newConfig' => 'bar',
        '4lw.commands.whitelist' => 'conf,isro,mntr,ruok,stat',
        'syncLimit' => 3,
        'initLimit' => 8,
        'dataDir' => '/toto',
        'clientPort' => 2181
      }
    end
    let(:expected) do
      <<~EXPECTED_FILE
      clientPort=2181
      dataDir=/toto
      initLimit=8
      syncLimit=3
      4lw.commands.whitelist=conf,isro,mntr,ruok,stat
      admin.enableServer=true
      tcpKeepAlive=true
      reconfigEnabled=true
      cnxTimeout=5
      dynamicConfigFile=/opt/zookeeper-3.5.8/conf/zoo.cfg.dynamic.2060000086c
      newConfig=bar
      EXPECTED_FILE
    end
    let(:subject) do
      existing = Zk::ZookeeperConfig.from_text(existing_text_config)
      update = Zk::ZookeeperConfig.from_h(updated_hash_config)
      existing.apply!(update).to_s
    end
    it 'keeps order of original fields, and adds new fields at the end' do
      expect(subject).to eq expected
    end
  end

  describe '#apply' do
    let(:existing_hash) do
      { 'keyA' => 'valueA', 'keyB' => 'valueB', 'keyC' => 'valueC' }
    end

    let(:existing_config) do
      Zk::ZookeeperConfig.from_h(existing_hash)
    end

    let(:update_hash) do
      { 'keyC' => 'valueC', 'keyD' => 'valueD', 'keyA' => 'valueE' }
    end

    let(:update_config) do
      Zk::ZookeeperConfig.from_h(update_hash)
    end

    let(:subject) do
      existing_config.apply!(update_config)
    end

    it 'updates existing fields' do
      expect(subject.fetch('keyA')).to eq 'valueE'
    end

    it 'removes removed fields' do
      expect(subject.key?('keyB')).to be_falsy
    end

    it 'adds added fields' do
      expect(subject.fetch('keyD')).to eq 'valueD'
    end

    it 'keeps order of updated fields' do
      expect(subject.index('keyA')).to eq existing_config.index('keyA')
    end

    it 'does not alter update object' do
      subject
      expect(update_config.to_s).to eq Zk::ZookeeperConfig.from_h(update_hash).to_s
    end

    context 'there is no change' do
      let(:update_hash) { existing_hash }
      it 'is idempotent' do
        expect(subject.to_s).to eq existing_config.to_s
      end
    end

    context 'with immutable_fields in previous and new conf' do
      before do
        existing_hash.merge!({ 'dynamicConfigFile' => 'good' })
        update_hash.merge!({ 'dynamicConfigFile' => 'bad' })
      end
      it 'does not update them' do
        expect(existing_config.fetch('dynamicConfigFile')).to eq 'good'
        expect(update_config.fetch('dynamicConfigFile')).to eq 'bad'
        expect(subject.fetch('dynamicConfigFile')).to eq 'good'
      end
    end
    context 'with immutable_fields in previous conf only' do
      before do
        existing_hash.merge!({ 'dynamicConfigFile' => 'good' })
      end
      it 'is preserved' do
        expect(subject.fetch('dynamicConfigFile')).to eq 'good'
      end
    end
    context 'with immutable_fields in new conf only' do
      before do
        update_hash.merge!({ 'dynamicConfigFile' => 'good' })
      end
      it 'is not created' do
        expect(subject.key?('dynamicConfigFile')).to be_falsy
      end
    end
  end
end

RSpec.describe Zk::ZookeeperDynamicConfig do
  let(:api_config) do
    <<~API
      server.1=1.1.1.1:2888:3888:participant;0.0.0.0:2181
      server.2=2.2.2.2:2888:3888:participant;0.0.0.0:2181
      version=20a00015b38
    API
  end
  let(:hash_config) do
    { 'server.1' => '1.1.1.1:2888:3888', 'server.2' => '2.2.2.2:2888:3888' }
  end
  let(:expected_api_call) do
    'server.1=1.1.1.1:2888:3888;2181,server.2=2.2.2.2:2888:3888;2181'
  end

  describe '#from_h' do
    it 'generates a valid object' do
      subject = Zk::ZookeeperDynamicConfig.from_h(hash_config)
      expect(subject.size).to eq 2
    end
  end

  describe '#from_api' do
    it 'generates a valid object' do
      subject = Zk::ZookeeperDynamicConfig.from_api(api_config)
      expect(subject.size).to eq 2
    end
  end

  describe '#==?' do
    # NOTE: Let's not test too much as we rely on ruby comparisons
    let(:subject) { object_from_api == object_from_hash }
    let(:object_from_api) { Zk::ZookeeperDynamicConfig.from_api(api_config) }

    context 'api and resource match' do
      let(:object_from_hash) { Zk::ZookeeperDynamicConfig.from_h(hash_config) }

      it 'returns true' do
        expect(subject).to be_truthy
      end
    end

    context 'api and resource match in reverse order' do
      let(:object_from_hash) do
        Zk::ZookeeperDynamicConfig.from_h({ 'server.2' => '2.2.2.2:2888:3888', 'server.1' => '1.1.1.1:2888:3888' })
      end

      it 'returns true' do
        expect(subject).to be_truthy
      end
    end
    context 'api and resource dont match one internal port' do
      let(:object_from_hash) do
        Zk::ZookeeperDynamicConfig.from_h({ 'server.1' => '1.1.1.1:2888:3888', 'server.2' => '2.2.2.2:2888:3898' })
      end

      it 'returns false' do
        expect(subject).to be_falsy
      end
    end
    context 'api and resource dont match hostname' do
      let(:object_from_hash) do
        Zk::ZookeeperDynamicConfig.from_h({ 'server.1' => '0.0.0.0:2888:3888', 'server.2' => '2.2.2.2:2888:3888' })
      end

      it 'returns false' do
        expect(subject).to be_falsy
      end
    end
  end

  describe '#to_s' do
    it 'returns a correct API config from from_h' do
      config = Zk::ZookeeperDynamicConfig.from_h(hash_config)
      expect(config.to_s).to eq expected_api_call
    end
    it 'returns a correct API config from from_api' do
      config = Zk::ZookeeperDynamicConfig.from_api(api_config)
      expect(config.to_s).to eq expected_api_call
    end
  end
end
