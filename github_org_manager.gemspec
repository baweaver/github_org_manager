# frozen_string_literal: true

require_relative "lib/github_org_manager/version"

Gem::Specification.new do |spec|
  spec.name = "github_org_manager"
  spec.version = GithubOrgManager::VERSION
  spec.authors = ["Brandon Weaver"]
  spec.email = ["keystonelemur@gmail.com"]

  spec.summary = "Manage GitHub organizations"
  # spec.description = "TODO"
  spec.homepage = "https://www.github.com/baweaver/github_org_manager"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "octokit", "~> 4.22.0"
  spec.add_dependency "netrc", "~> 0.11.0"

  spec.add_development_dependency "rspec", "~> 3.11.0"
  spec.add_development_dependency "guard-rspec", "~> 4.7.3"
end
