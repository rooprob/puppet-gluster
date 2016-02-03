require 'spec_helper'
require 'unit/helpers'

volume_type = Puppet::Type.type(:gluster_volume)

describe volume_type.provider(:gluster_volume), :unit => true do
  before :all do
    # If we've run integration tests before this, we'll already have a default
    # provider that will break our prefetch tests. Calling `unprovide` has the
    # side effect of actually deleting the provider class, which breaks our
    # coverage measurement. To avoid this, we call unprovide once before
    # running these unit tests instead of calling it after running the
    # integration tests. Yay puppet.
    described_class.resource_type.unprovide(:gluster_volume)
  end

  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        stub_facts(facts)
        @fake_gluster = stub_gluster(described_class)
        @volume_type = described_class.resource_type
      end

      describe 'class methods' do
        [:instances, :prefetch, :peers_present, :all_volumes].each do |method|
          it "should have method named #{method}" do
            expect(described_class).to respond_to method
          end
        end
      end

      context 'without volumes' do
        it 'should return no resources' do
          expect(props(described_class.instances)).to eq([])
        end

        it 'should prefetch no providers' do
          res = [1, 2, 3].map { |n| @volume_type.new(:name => "vol#{n}") }
          expect(res_providers(res)).to eq([nil, nil, nil])
          described_class.prefetch(res_hash(res))
          expect(res_providers(res)).to eq([nil, nil, nil])
        end

        describe 'a new volume' do
          before :each do
            @new_volume = described_class.new(
              @volume_type.new(:name => 'vol1', :replica => 2, :bricks => [
                  'gfs1.local:/b1/vol1',
                  'gfs2.local:/b1/vol1',
                ]))
          end

          it 'should not exist' do
            expect(@new_volume.get(:ensure)).to eq(:absent)
          end

          it 'should be created and started' do
            @fake_gluster.add_peers('gfs1.local', 'gfs2.local')
            expect(@fake_gluster.volume_names).to eq([])
            @new_volume.create
            expect(@fake_gluster.volume_names).to eq(['vol1'])
            expect(@new_volume.get(:ensure)).to eq(:present)
            # TODO: Check various properties.
          end

          it 'should be created without being started' do
            @fake_gluster.add_peers('gfs1.local', 'gfs2.local')
            expect(@fake_gluster.volume_names).to eq([])
            @new_volume.ensure_stopped
            expect(@fake_gluster.volume_names).to eq(['vol1'])
            expect(@new_volume.get(:ensure)).to eq(:stopped)
            # TODO: Check various properties.
          end
        end
      end

      context 'with one volume' do
        before :each do
          @fake_gluster.add_volumes({
              :name => 'vol1',
              :replica => 2,
              :bricks => ['gfs1.local:/b1/vol1', 'gfs2.local:/b1/vol1'],
            })
        end

        it 'should return one resource' do
          expect(props(described_class.instances)).to eq([{
                :name => 'vol1',
                :ensure => :present,
              }])
        end

        it 'should prefetch one provider' do
          res = [1, 2, 3].map { |n| @volume_type.new(:name => "vol#{n}") }
          expect(res_providers(res)).to eq([nil, nil, nil])
          described_class.prefetch(res_hash(res))
          expect(res_providers(res)).to eq(['vol1', nil, nil])
        end

        describe 'a new volume' do
          before :each do
            @new_volume = described_class.new(
              @volume_type.new(:name => 'vol2', :replica => 2, :bricks => [
                  'gfs1.local:/b1/vol2',
                  'gfs2.local:/b1/vol2',
                ]))
          end

          it 'should not exist' do
            expect(@new_volume.get(:ensure)).to eq(:absent)
          end

          it 'should be created and started' do
            @fake_gluster.add_peers('gfs1.local', 'gfs2.local')
            expect(@fake_gluster.volume_names).to eq(['vol1'])
            @new_volume.create
            expect(@fake_gluster.volume_names).to eq(['vol1', 'vol2'])
            expect(@new_volume.get(:ensure)).to eq(:present)
            # TODO: Check various properties.
          end

          it 'should be created and started with force' do
            @fake_gluster.add_peers('gfs1.local', 'gfs2.local')
            @new_volume.resource[:force] = true
            expect(@fake_gluster.volume_names).to eq(['vol1'])
            @new_volume.create
            expect(@fake_gluster.volume_names).to eq(['vol1', 'vol2'])
            expect(@new_volume.get(:ensure)).to eq(:present)
            # TODO: Check that force was actually used.
          end

          it 'should be created without being started' do
            @fake_gluster.add_peers('gfs1.local', 'gfs2.local')
            expect(@fake_gluster.volume_names).to eq(['vol1'])
            @new_volume.ensure_stopped
            expect(@fake_gluster.volume_names).to eq(['vol1', 'vol2'])
            expect(@new_volume.get(:ensure)).to eq(:stopped)
            # TODO: Check various properties.
          end
        end

        describe 'an existing volume' do
          before :each do
            (@volume,) = described_class.instances
            @volume.resource = @volume_type.new(
              :name => 'vol1', :ensure => :present)
          end

          it 'should exist' do
            expect(@volume.get(:ensure)).to eq(:present)
          end

          it 'should be destroyed' do
            expect(@fake_gluster.volume_names).to eq(['vol1'])
            @volume.destroy
            expect(@fake_gluster.volume_names).to eq([])
            expect(@volume.get(:ensure)).to eq(:absent)
            # TODO: Check various properties.
          end

          it 'should be stopped' do
            @fake_gluster.add_peers('gfs1.local', 'gfs2.local')
            expect(@fake_gluster.volume_names).to eq(['vol1'])
            @volume.ensure_stopped
            expect(@fake_gluster.volume_names).to eq(['vol1'])
            expect(@volume.get(:ensure)).to eq(:stopped)
            # TODO: Check various properties.
          end

        end

      end

      context 'with two volumes' do
        before :each do
          @fake_gluster.add_volumes({
              :name => 'vol1',
              :replica => 2,
              :bricks => ['gfs1.local:/b1/vol1', 'gfs2.local:/b1/vol1'],
            }, {
              :name => 'vol2',
              :bricks => ['gfs1.local:/b1/vol2', 'gfs2.local:/b1/vol2'],
            })
        end

        it 'should return two resources' do
          expect(props(described_class.instances)).to eq([{
                :name => 'vol1',
                :ensure => :present,
              }, {
                :name => 'vol2',
                :ensure => :present,
              }])
        end

        it 'should prefetch two providers' do
          res = [1, 2, 3].map { |n| @volume_type.new(:name => "vol#{n}") }
          expect(res_providers(res)).to eq([nil, nil, nil])
          described_class.prefetch(res_hash(res))
          expect(res_providers(res)).to eq(['vol1', 'vol2', nil])
        end
      end

    end
  end
end
