require 'spec_helper'
require_relative '../../../libraries/default.rb'

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
      "itemA=valueA\nitemB=valueB"
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
