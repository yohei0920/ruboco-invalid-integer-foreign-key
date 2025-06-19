# frozen_string_literal: true

require_relative 'lib/rubocop/fk/bigint/checker/version'

Gem::Specification.new do |spec|
  spec.name = 'rubocop-fk-bigint-checker'
  spec.version = Rubocop::Fk::Bigint::Checker::VERSION
  spec.authors = ['yohei.hokari']
  spec.email = ['yohei.hokari@gmail.com']

  spec.summary = 'RuboCop cop to check foreign key type mismatches in Rails schema files'
  spec.description = "A RuboCop cop that detects when foreign keys use integer type but the referenced table's primary key is bigint, helping prevent type mismatches in Rails applications."
  spec.homepage = 'https://github.com/your-username/rubocop-fk-bigint-checker'
  spec.required_ruby_version = '>= 3.1.0'
  spec.license = 'MIT'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Add RuboCop as a dependency
  spec.add_dependency 'rubocop', '>= 1.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.0'

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
