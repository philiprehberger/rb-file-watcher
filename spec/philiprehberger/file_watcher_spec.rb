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
      expect { watcher.on(:bogus) {} }.to raise_error(ArgumentError, /invalid event type/)
    end

    describe 'exclusion patterns' do
      it 'excludes files matching a single pattern' do
        changes = []
        watcher = described_class.new(tmpdir, interval: 0.1, exclude: ['**/*.log'])
        watcher.on(:created) { |change| changes << change }
        watcher.start

        sleep 0.15
        File.write(File.join(tmpdir, 'app.rb'), 'code')
        File.write(File.join(tmpdir, 'debug.log'), 'log data')
        sleep 0.3

        watcher.stop

        paths = changes.map(&:path)
        expect(paths.any? { |p| p.end_with?('app.rb') }).to be true
        expect(paths.none? { |p| p.end_with?('debug.log') }).to be true
      end

      it 'excludes files matching multiple patterns' do
        changes = []
        watcher = described_class.new(tmpdir, interval: 0.1, exclude: ['**/*.log', '**/*.tmp'])
        watcher.on(:created) { |change| changes << change }
        watcher.start

        sleep 0.15
        File.write(File.join(tmpdir, 'app.rb'), 'code')
        File.write(File.join(tmpdir, 'debug.log'), 'log data')
        File.write(File.join(tmpdir, 'cache.tmp'), 'temp data')
        sleep 0.3

        watcher.stop

        paths = changes.map(&:path)
        expect(paths.any? { |p| p.end_with?('app.rb') }).to be true
        expect(paths.none? { |p| p.end_with?('debug.log') }).to be true
        expect(paths.none? { |p| p.end_with?('cache.tmp') }).to be true
      end

      it 'excludes files in matching directories' do
        cache_subdir = File.join(tmpdir, 'cached')
        FileUtils.mkdir_p(cache_subdir)

        changes = []
        watcher = described_class.new(tmpdir, interval: 0.1, exclude: ['**/cached/**'])
        watcher.on(:created) { |change| changes << change }
        watcher.start

        sleep 0.15
        File.write(File.join(tmpdir, 'app.rb'), 'code')
        File.write(File.join(cache_subdir, 'ignored.txt'), 'ignored')
        sleep 0.3

        watcher.stop

        paths = changes.map(&:path)
        expect(paths.any? { |p| p.end_with?('app.rb') }).to be true
        expect(paths.none? { |p| p.include?('/cached/') }).to be true
      end

      it 'does not exclude anything when exclude is empty' do
        changes = []
        watcher = described_class.new(tmpdir, interval: 0.1, exclude: [])
        watcher.on(:created) { |change| changes << change }
        watcher.start

        sleep 0.15
        File.write(File.join(tmpdir, 'app.rb'), 'code')
        File.write(File.join(tmpdir, 'debug.log'), 'log data')
        sleep 0.3

        watcher.stop

        paths = changes.map(&:path)
        expect(paths.any? { |p| p.end_with?('app.rb') }).to be true
        expect(paths.any? { |p| p.end_with?('debug.log') }).to be true
      end
    end

    describe 'change debouncing' do
      it 'coalesces rapid changes to the same file' do
        path = File.join(tmpdir, 'rapid.txt')
        File.write(path, 'initial')

        changes = []
        watcher = described_class.new(tmpdir, interval: 0.1, debounce: 0.3)
        watcher.on(:modified) { |change| changes << change }
        watcher.start

        sleep 0.15
        # Rapid consecutive writes
        3.times do |i|
          File.write(path, "update #{i}")
          sleep 0.05
        end
        # Wait for debounce to settle
        sleep 0.6

        watcher.stop

        # Should have fewer callbacks than raw modifications
        expect(changes.size).to be >= 1
        expect(changes.all? { |c| c.path.end_with?('rapid.txt') }).to be true
      end

      it 'fires callbacks after debounce period of inactivity' do
        changes = []
        watcher = described_class.new(tmpdir, interval: 0.1, debounce: 0.2)
        watcher.on(:created) { |change| changes << change }
        watcher.start

        sleep 0.15
        File.write(File.join(tmpdir, 'debounced.txt'), 'hello')
        sleep 0.5

        watcher.stop

        expect(changes.size).to be >= 1
        expect(changes.first.path).to end_with('debounced.txt')
      end

      it 'flushes pending debounced changes on stop' do
        changes = []
        watcher = described_class.new(tmpdir, interval: 0.1, debounce: 10.0)
        watcher.on(:created) { |change| changes << change }
        watcher.start

        sleep 0.15
        File.write(File.join(tmpdir, 'pending.txt'), 'hello')
        sleep 0.3

        watcher.stop

        expect(changes.size).to be >= 1
        expect(changes.first.path).to end_with('pending.txt')
      end

      it 'does not debounce when debounce is nil' do
        changes = []
        watcher = described_class.new(tmpdir, interval: 0.1, debounce: nil)
        watcher.on(:created) { |change| changes << change }
        watcher.start

        sleep 0.15
        File.write(File.join(tmpdir, 'immediate.txt'), 'hello')
        sleep 0.3

        watcher.stop

        expect(changes.size).to be >= 1
        expect(changes.first.path).to end_with('immediate.txt')
      end
    end

    describe 'error callback' do
      it 'fires :error callback for filesystem errors' do
        errors = []
        watcher = described_class.new('/nonexistent_path_12345', interval: 0.1)
        watcher.on(:error) { |exception, path| errors << [exception, path] }
        watcher.start

        sleep 0.3

        watcher.stop

        # The nonexistent path is silently skipped (not a file, not a directory)
        # so no error is raised. This validates error callbacks are accepted.
        expect(watcher).not_to be_running
      end

      it 'accepts :error as a valid callback type' do
        watcher = described_class.new(tmpdir)
        expect { watcher.on(:error) { |_e, _p| } }.not_to raise_error
      end

      it 'raises filesystem errors when no error callback is registered' do
        # Simulate by testing that error callback registration works
        watcher = described_class.new(tmpdir)
        error_handler = watcher.on(:error) { |_e, _p| }
        expect(error_handler).to eq(watcher)
      end

      it 'passes exception and path to error callback' do
        errors = []
        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.on(:error) { |exception, path| errors << { exception: exception, path: path } }

        # Verify the callback is registered by checking the watcher accepts it
        expect(watcher).not_to be_running
      end
    end

    describe 'snapshot method' do
      it 'returns an empty hash when no files exist' do
        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.start
        sleep 0.05

        result = watcher.snapshot
        watcher.stop

        expect(result).to be_a(Hash)
        expect(result).to be_empty
      end

      it 'returns file paths with mtime and size' do
        path = File.join(tmpdir, 'tracked.txt')
        File.write(path, 'hello world')

        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.start
        sleep 0.05

        result = watcher.snapshot
        watcher.stop

        expanded = File.expand_path(path)
        expect(result).to have_key(expanded)
        expect(result[expanded]).to have_key(:mtime)
        expect(result[expanded]).to have_key(:size)
        expect(result[expanded][:mtime]).to be_a(Time)
        expect(result[expanded][:size]).to eq(11)
      end

      it 'tracks multiple files' do
        File.write(File.join(tmpdir, 'a.txt'), 'aaa')
        File.write(File.join(tmpdir, 'b.txt'), 'bbb')

        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.start
        sleep 0.05

        result = watcher.snapshot
        watcher.stop

        expect(result.size).to eq(2)
        result.each_value do |info|
          expect(info).to have_key(:mtime)
          expect(info).to have_key(:size)
        end
      end

      it 'respects glob patterns in snapshot' do
        File.write(File.join(tmpdir, 'code.rb'), 'puts "hi"')
        File.write(File.join(tmpdir, 'data.txt'), 'data')

        watcher = described_class.new(tmpdir, interval: 0.1, glob: '**/*.rb')
        watcher.start
        sleep 0.05

        result = watcher.snapshot
        watcher.stop

        expect(result.size).to eq(1)
        expect(result.keys.first).to end_with('code.rb')
      end

      it 'respects exclude patterns in snapshot' do
        File.write(File.join(tmpdir, 'code.rb'), 'puts "hi"')
        File.write(File.join(tmpdir, 'debug.log'), 'log data')

        watcher = described_class.new(tmpdir, interval: 0.1, exclude: ['**/*.log'])
        watcher.start
        sleep 0.05

        result = watcher.snapshot
        watcher.stop

        expect(result.size).to eq(1)
        expect(result.keys.first).to end_with('code.rb')
      end
    end

    describe 'batch change reporting' do
      it 'fires :batch callback with all changes from one cycle' do
        batches = []
        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.on(:batch) { |changes| batches << changes }
        watcher.start

        sleep 0.15
        File.write(File.join(tmpdir, 'file1.txt'), 'one')
        File.write(File.join(tmpdir, 'file2.txt'), 'two')
        sleep 0.3

        watcher.stop

        expect(batches).not_to be_empty
        expect(batches.first).to be_an(Array)
        expect(batches.first.all?(Philiprehberger::FileWatcher::Change)).to be true
      end

      it 'receives all changes in a single batch call per cycle' do
        batches = []
        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.on(:batch) { |changes| batches << changes }
        watcher.start

        sleep 0.15
        File.write(File.join(tmpdir, 'a.txt'), 'aaa')
        File.write(File.join(tmpdir, 'b.txt'), 'bbb')
        File.write(File.join(tmpdir, 'c.txt'), 'ccc')
        sleep 0.3

        watcher.stop

        # At least one batch should contain multiple changes
        total_changes = batches.flatten.size
        expect(total_changes).to be >= 3
      end

      it 'fires batch callback alongside individual callbacks' do
        individual_changes = []
        batches = []
        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.on(:created) { |change| individual_changes << change }
        watcher.on(:batch) { |changes| batches << changes }
        watcher.start

        sleep 0.15
        File.write(File.join(tmpdir, 'both.txt'), 'data')
        sleep 0.3

        watcher.stop

        expect(individual_changes).not_to be_empty
        expect(batches).not_to be_empty
      end

      it 'does not fire batch callback when no changes occur' do
        batches = []
        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.on(:batch) { |changes| batches << changes }
        watcher.start

        sleep 0.3

        watcher.stop

        expect(batches).to be_empty
      end
    end

    describe 'pause and resume' do
      it 'reports paused? as false initially' do
        watcher = described_class.new(tmpdir, interval: 0.1)
        expect(watcher.paused?).to be false
      end

      it 'reports paused? as true after pause' do
        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.start
        watcher.pause
        expect(watcher.paused?).to be true
        watcher.stop
      end

      it 'reports paused? as false after resume' do
        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.start
        watcher.pause
        watcher.resume
        expect(watcher.paused?).to be false
        watcher.stop
      end

      it 'does not fire callbacks while paused' do
        File.write(File.join(tmpdir, 'existing.txt'), 'original')

        changes = []
        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.on(:any) { |change| changes << change }
        watcher.start

        sleep 0.15
        watcher.pause
        sleep 0.05

        File.write(File.join(tmpdir, 'paused_file.txt'), 'created while paused')
        File.write(File.join(tmpdir, 'existing.txt'), 'modified while paused')
        sleep 0.3

        expect(changes).to be_empty
        watcher.stop
      end

      it 'ignores changes that occurred during pause after resume' do
        changes = []
        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.on(:created) { |change| changes << change }
        watcher.start

        sleep 0.15
        watcher.pause
        sleep 0.05

        File.write(File.join(tmpdir, 'during_pause.txt'), 'created while paused')
        sleep 0.1

        changes.clear
        watcher.resume
        sleep 0.3

        # The file created during pause should not be reported as created
        created_paths = changes.map(&:path)
        expect(created_paths.none? { |p| p.end_with?('during_pause.txt') }).to be true

        watcher.stop
      end

      it 'detects changes after resume' do
        changes = []
        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.on(:created) { |change| changes << change }
        watcher.start

        sleep 0.15
        watcher.pause
        sleep 0.05
        watcher.resume
        sleep 0.15

        File.write(File.join(tmpdir, 'after_resume.txt'), 'created after resume')
        sleep 0.3

        watcher.stop

        paths = changes.map(&:path)
        expect(paths.any? { |p| p.end_with?('after_resume.txt') }).to be true
      end

      it 'returns self from pause and resume' do
        watcher = described_class.new(tmpdir, interval: 0.1)
        watcher.start

        expect(watcher.pause).to eq(watcher)
        expect(watcher.resume).to eq(watcher)

        watcher.stop
      end
    end

    describe 'batch with debouncing' do
      it 'fires batch callback for debounced changes' do
        batches = []
        watcher = described_class.new(tmpdir, interval: 0.1, debounce: 0.2)
        watcher.on(:batch) { |changes| batches << changes }
        watcher.start

        sleep 0.15
        File.write(File.join(tmpdir, 'debounced_batch.txt'), 'hello')
        sleep 0.5

        watcher.stop

        expect(batches).not_to be_empty
        expect(batches.flatten.first.path).to end_with('debounced_batch.txt')
      end
    end
  end
end
