# GithubOrgManager

A manager for Github Organizations. When onboarding onto a new organization it can be tedious to `git clone` several repos, and after joining even more annoying keeping them all up to date. This gem aims to fix both:

```ruby
require "github_org_manager"

manager = GithubOrgManager::Manager.new(
  # The name of the organization you want to manage, or
  # more accurately read from for now.
  org_name: "<YOUR_ORG_HERE>",

  # If you would like to limit this to only teams that the
  # "logged in" user currently belongs to, set this to
  # true and all downloads and updates will be scoped as
  # such.
  team_only: true,

  # Directory where your code typically is, defaults to
  # `~/dev` and ensures it exists
  dev_home: "<WHERE_YOUR_CODE_LIVES>",

  # Params for logging into Octokit, defaulting
  # to `.netrc` login ( https://github.com/octokit/octokit.rb#using-a-netrc-file )
  octokit_params: "<PARAMS_FOR_OCTOKIT>",

  # Configuration block passed directly to
  # `Octokit.configure`
  &octokit_configuration
)

# Make sure that all the repos are currently cloned and exist in
# `dev_home/org_name/repo_name`.
manager.ensure_repo_directories_exist!

# Updates all repos by pulling latest changes after stashing existing
# changes and changing to the main branch of the repo.
#
# Note that this will run `ensure_repo_directories_exist!` to make sure
# that the directories and projects we're trying to update actually exist
manager.update_repos!
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'github_org_manager'
```

And then execute:

```sh
$ bundle install
```

Or install it yourself as:

```sh
$ gem install github_org_manager
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/baweaver/github_org_manager. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/baweaver/github_org_manager/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the GithubOrgManager project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/baweaver/github_org_manager/blob/main/CODE_OF_CONDUCT.md).
