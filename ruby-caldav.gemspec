# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require File.expand_path('lib/ruby-caldav/version', __dir__)

Gem::Specification.new do |s|
  s.name        = 'ruby-caldav'
  s.version     = CalDAV::VERSION
  s.summary     = 'Ruby CalDAV client'
  s.description = 'Ruby client for searching, creating, editing CalDAV calendars and tasks.'

  s.required_ruby_version = '>= 1.9.3'

  s.license     = 'MIT'

  s.homepage    = 'https://github.com/sonicdes/ruby-caldav'
  s.authors     = ['Denis Sadomowski']
  s.email       = ['sonicdes@gmail.com']
  s.add_dependency 'builder', '~> 3.x'
  s.add_dependency 'icalendar', '~> 1.x'
  s.add_dependency 'net-http-digest_auth', '~> 1.x'
  s.add_dependency 'rexml'
  s.add_dependency 'uuid', '~> 2.x'
  s.add_development_dependency 'fakeweb', '~> 1.x'
  s.add_development_dependency 'rspec', '~> 2.x'

  s.description = <<-DESC
  Ruby client for searching, creating, editing CalDAV calendars and tasks.
  DESC

  s.files         = `git ls-files`.split("\n")
  s.require_paths = ['lib']
end
