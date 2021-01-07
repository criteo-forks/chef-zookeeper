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
      { 'keyC' => 'valueC', 'keyD' => 'valueD', 'keyA' => 'valueE'}
    end

    let(:update_config) do
      Zk::ZookeeperConfig.from_h(update_hash)
    end

    let(:subject) do
      existing_config.apply!(update_config)
    end

    it 'updates existing fields' do
      expect(subject.value('keyA')).to eq 'valueE'
    end

    it 'removes removed fields' do
      expect(subject.haskey?('keyB')).to be_falsy
    end

    it 'adds added fields' do
      expect(subject.value('keyD')).to eq 'valueD'
    end

    it 'keeps order of updated fields' do
      new_entry = subject.config.find{ |k| k.keys.first == 'keyA'}
      old_entry = existing_config.config.find{ |k| k.keys.first == 'keyA'}

      expect(subject.config.index(new_entry)).to eq existing_config.config.index(old_entry)
    end

    context 'with immutable_fields in conf' do
      before do
        existing_hash.merge!({ 'dynamicConfigFile' => 'good' })
        update_hash.merge!({ 'dynamicConfigFile' => 'bad' })
      end
      it 'does not update them' do
        expect(subject.value('dynamicConfigFile')).to eq 'good'
      end
    end

  end
end
