# frozen_string_literal: true

require 'bundler/gem_tasks'

namespace :version do
  desc 'Bump major version (X.y.z)'
  task :major do
    bump_version(:major)
  end

  desc 'Bump minor version (x.Y.z)'
  task :minor do
    bump_version(:minor)
  end

  desc 'Bump patch version (x.y.Z)'
  task :patch do
    bump_version(:patch)
  end

  def bump_version(type)
    version_file = 'lib/last_llm/version.rb'
    content = File.read(version_file)
    current_version = content.match(/VERSION\s*=\s*['"](\d+\.\d+\.\d+)['"]/)[1]
    major, minor, patch = current_version.split('.').map(&:to_i)

    case type
    when :major
      major += 1
      minor = 0
      patch = 0
    when :minor
      minor += 1
      patch = 0
    when :patch
      patch += 1
    end

    new_version = "#{major}.#{minor}.#{patch}"
    new_content = content.gsub(/VERSION\s*=\s*['"](\d+\.\d+\.\d+)['"]/, "VERSION = '#{new_version}'")
    
    File.write(version_file, new_content)
    puts "Version bumped to #{new_version}"
  end
end

namespace :release do
  desc 'Build and push gem to RubyGems'
  task :push do
    system('gem build last_llm.gemspec') || abort('Gem build failed')
    gem_file = Dir['last_llm-*.gem'].sort_by { |f| File.mtime(f) }.last
    system("gem push #{gem_file}") || abort('Gem push failed')
    FileUtils.rm(gem_file)
    puts "Successfully released #{gem_file}"
  end
end

desc 'Bump version, build and push gem (usage: rake release[patch])'
task :release, [:type] => [:clean] do |_, args|
  type = (args[:type] || 'patch').to_sym
  unless %i[major minor patch].include?(type)
    abort "Invalid version type. Use 'major', 'minor', or 'patch'"
  end

  Rake::Task["version:#{type}"].invoke
  Rake::Task['release:push'].invoke
end