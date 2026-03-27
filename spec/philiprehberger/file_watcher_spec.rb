# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Philiprehberger::FileWatcher do
  it 'has a version number' do
    expect(Philiprehberger::FileWatcher::VERSION).not_to be_nil
  end

  describe Philiprehberger::FileWatcher::Change do
    it 'stores path and type' do
      change = described_class.new('/tmp/test.txt', :created)
      expect(change.path).to eq('/tmp/test.txt')
      expect(change.type).to eq(:created)
    end

    it 'rejects invalid types' do
      expect { described_class.new('/tmp/test.txt', :unknown) }.to raise_error(ArgumentError, /invalid change type/)
    end

    it 'formats to_s' do
      change = described_class.new('/tmp/test.txt', :modified)
      expect(change.to_s).to eq('modified: /tmp/test.txt')
    end

    it 'supports equality' do
      a = described_class.new('/tmp/test.txt', :created)
      b = described_class.new('/tmp/test.txt', :created)
      c = described_class.new('/tmp/other.txt', :created)

      expect(a).to eq(b)
      expect(a).not_to eq(c)
    end
  end

  describe Philiprehberger::FileWatcher::Watcher do
    let(:tmpdir) { Dir.mktmpdir('file_watcher_test') }

    after { FileUtils.rm_rf(tmpdir) }

    it 'detects file creation' do
      changes = []
      watcher = described_class.new(tmpdir, interval: 0.1)
      watcher.on(:created) { |change| changes << change }
      watcher.start

      sleep 0.15
      File.write(File.join(tmpdir, 'new.txt'), 'hello')
      sleep 0.3

      watcher.stop

      expect(changes.size).to be >= 1
      expect(changes.first.type).to eq(:created)
      expect(changes.first.path).to end_with('new.txt')
    end

    it 'detects file modification' do
      path = File.join(tmpdir, 'existing.txt')
      File.write(path, 'original')

      changes = []
      watcher = described_class.new(tmpdir, interval: 0.1)
      watcher.on(:modified) { |change| changes << change }
      watcher.start

      sleep 0.15
      sleep 0.05 # ensure mtime differs
      File.write(path, 'updated')
      sleep 0.3

      watcher.stop

      expect(changes.size).to be >= 1
      expect(changes.first.type).to eq(:modified)
      expect(changes.first.path).to end_with('existing.txt')
    end

    it 'detects file deletion' do
      path = File.join(tmpdir, 'doomed.txt')
      File.write(path, 'goodbye')

      changes = []
      watcher = described_class.new(tmpdir, interval: 0.1)
      watcher.on(:deleted) { |change| changes << change }
      watcher.start

      sleep 0.15
      File.delete(path)
      sleep 0.3

      watcher.stop

      expect(changes.size).to be >= 1
      expect(changes.first.type).to eq(:deleted)
      expect(changes.first.path).to end_with('doomed.txt')
    end

    it 'fires :any callbacks for all change types' do
      changes = []
      watcher = described_class.new(tmpdir, interval: 0.1)
      watcher.on(:any) { |change| changes << change }
      watcher.start

      sleep 0.15
      File.write(File.join(tmpdir, 'any_test.txt'), 'data')
      sleep 0.3

      watcher.stop

      expect(changes).not_to be_empty
      expect(changes.first.type).to eq(:created)
    end

    it 'reports running? correctly' do
      watcher = described_class.new(tmpdir, interval: 0.1)

      expect(watcher.running?).to be false

      watcher.start
      expect(watcher.running?).to be true

      watcher.stop
      expect(watcher.running?).to be false
    end

    it 'stops the background thread' do
      watcher = described_class.new(tmpdir, interval: 0.1)
      watcher.start

      thread_count_before = Thread.list.count
      watcher.stop

      # Give a moment for thread cleanup
      sleep 0.05
      expect(Thread.list.count).to be <= thread_count_before
      expect(watcher.running?).to be false
    end

    it 'supports custom glob patterns' do
      changes = []
      watcher = described_class.new(tmpdir, interval: 0.1, glob: '**/*.rb')
      watcher.on(:created) { |change| changes << change }
      watcher.start

      sleep 0.15
      File.write(File.join(tmpdir, 'test.rb'), "puts 'hi'")
      File.write(File.join(tmpdir, 'test.txt'), 'ignored')
      sleep 0.3

      watcher.stop

      paths = changes.map(&:path)
      expect(paths.any? { |p| p.end_with?('test.rb') }).to be true
      expect(paths.none? { |p| p.end_with?('test.txt') }).to be true
    end

    it 'rejects invalid event types' do
      watcher = described_class.new(tmpdir)
      expect { watcher.on(:bogus) {} }.to raise_error(ArgumentError, /invalid event type/) # rubocop:disable Lint/EmptyBlock
    end
  end
end
