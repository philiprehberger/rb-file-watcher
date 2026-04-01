# frozen_string_literal: true

require_relative 'lib/philiprehberger/file_watcher/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-file_watcher'
  spec.version = Philiprehberger::FileWatcher::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']
  spec.summary = 'File system change detection with polling and callbacks'
  spec.description = 'Watch files and directories for changes using polling. Detects created, modified, ' \
                     'and deleted files with configurable intervals and glob patterns.'
  spec.homepage = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-file_watcher'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/philiprehberger/rb-file-watcher'
  spec.metadata['changelog_uri'] = 'https://github.com/philiprehberger/rb-file-watcher/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/philiprehberger/rb-file-watcher/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
