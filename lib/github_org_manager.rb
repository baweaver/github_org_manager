# frozen_string_literal: true

require_relative "github_org_manager/version"

require "octokit"
require "netrc"

module GithubOrgManager
  # Manages an organization in GitHub, currently in a
  # READONLY fashion for syncing purposes.
  #
  class Manager
    # Where your development files are stored
    DEV_HOME = File.join(Dir.home, "dev")

    # Default login params for Octokit, currently
    # relies on OAuth tokens in `~/.netrc`:
    #
    # ( https://github.com/octokit/octokit.rb#using-a-netrc-file )
    OCTOKIT_PARAMS = { netrc: true }

    attr_reader :client, :dev_home, :org_name, :username

    # Creates a new Manager
    #
    # @param org_name: [String]
    #   Organization to pull data from.
    #
    # @param team_only: [Boolean]
    #   Scope all data to only teams in the organization
    #   you belong to, meaning all syncing applies only to
    #   teams you're specifically on.
    #
    # @param dev_home: [String]
    #   Where development files and repos live on your machine.
    #
    # @param octokit_params [Hash<Symbol, Any>]
    #   Params passed through to `Octokit::Client` constructor.
    #
    # @param &octokit_configuration [Proc]
    #   Configuration block passed to `Octokit.configure`.
    def initialize(
      org_name:,
      team_only: false,
      dev_home: DEV_HOME,
      octokit_params: OCTOKIT_PARAMS,
      &octokit_configuration
    )
      path_name = Pathname.new(dev_home)
      File.directory?(path_name) or raise "Directory does not exist: #{path_name}"

      @dev_home = path_name
      @org_name = org_name
      @org_path = File.join(@dev_home, org_name)

      @client   = get_client(octokit_params:, &octokit_configuration)
      @username = client.user[:login]
      @team_only = team_only
    end

    # Repositories in the organization the Manager is targeting. These
    # values can be scoped to only ones owned by the username specified
    # to Octokit with the `team_only` option.
    #
    # @return [Hash<String, String>]
    #   Mapping of repo name to repo URL
    def repos
      @repos ||= @team_only ? my_repos : team_repos
    end

    # File paths of all repos currently in scope for your organization.
    #
    # @return [Hash<String, String>]
    #   Mapping of repo name to repo file path.
    def repo_paths
      @repo_paths ||= repos.to_h do |repo_name, _repo_url|
        [repo_name, File.join(@org_path, repo_name)]
      end
    end

    # All unscoped repos belonging to an organization.
    #
    # @return [Hash<String, String>]
    #   Mapping of repo name to repo URL.
    def all_repos
      @all_repos ||= client.org_repos(@org_name).to_h do |repo_data|
        [repo_data[:name], repo_data[:html_url]]
      end
    end

    # Repos that the current user in Octokit is a member of a team.
    # of that manages that repo.
    #
    # @return [Hash<String, String>]
    #   Mapping of repo name to repo URL.
    def my_repos
      @my_repos ||= all_repos.select do |name, _|
        my_repo_names.include?(name)
      end
    end

    # Gets teams under the current organization.
    #
    # @return [Hash<String, Numeric>]
    #   Mapping of team name to team id.
    def org_teams
      @org_teams ||= client.org_teams(@org_name).to_h do
        [_1[:name], _1[:id]]
      end
    end

    # Repos that each team manages, may have overlaps.
    #
    # @return [Hash<String, Array<String>>]
    #   Mapping of team name to a collection of repo names
    #   that they manage.
    def team_repos
      @team_repos ||= org_teams.to_h do |name, id|
        [name, client.team_repos(id).map { _1[:name] }]
      end
    end

    # Members that belong to each team.
    #
    # @return [Hash<String, Array<String>>]
    #   Mapping of team name to a collection of all of its
    #   members.
    def team_members
      @team_members ||= org_teams.to_h do |name, id|
        [name, client.team_members(id).map { _1[:login] }]
      end
    end

    # Teams that the current logged in user belongs to.
    #
    # @return [Set<String>]
    #   Names of teams.
    def my_teams
      @my_teams ||= team_members
        .select { |_, members| members.include?(@username) }
        .keys
        .then { Set.new(_1) }
    end

    # Repos that the current logged in user has authority over.
    #
    # @return [Set<String>]
    #   Names of repos.
    def my_repo_names
      @my_repo_names ||= team_repos
        .select { |name, _| my_teams.include?(name) }
        .values
        .flatten
        .then { Set.new(_1) }
    end

    # Make sure that every repo in the organization exists on this
    # machine. Scoped to team if `team_only` is on.
    #
    # @return [void]
    def ensure_repo_directories_exist!
      Dir.mkdir(@org_path) unless Dir.exist?(@org_path)

      Dir.chdir(@org_path) do
        repos.each do |name, html_url|
          `git clone "#{html_url}"` unless Dir.exist?(@repo_paths[name])
        end
      end

      true
    end

    # Update all repos, scoped to team if `team_only` is on.
    #
    # TODO: While there is a Ruby Git gem I've had some difficulty
    # in getting it to work properly, hence plain old system commands
    # instead for the time being.
    #
    # @return [void]
    def update_repos!
      # Hard to update repos which don't exist on the computer, make sure that
      # we have them all already downloaded, or do so
      ensure_repo_directories_exist!

      puts "📦 Updating #{repo_paths.size} repos: \n"

      repo_paths.each do |name, path|
        Dir.chdir(path) do
          main_branch = `basename $(git symbolic-ref refs/remotes/origin/HEAD)` || "main"
          current_branch = `git rev-parse --abbrev-ref HEAD`
          on_main = main_branch == current_branch
          no_changes = `git diff --stat`.empty?

          puts "  Updating #{name}:"

          puts "    Stashing any potential changes" unless no_changes
          `git stash` unless no_changes

          puts "    Checking out #{main_branch}" unless on_main
          `git checkout #{main_branch}` unless on_main

          puts "    Pulling changes"
          `git pull`

          puts "    Returning to previous branch #{current_branch}" unless on_main
          `git checkout #{current_branch}` unless on_main

          puts "    Popping stash" unless no_changes
          `git stash pop` unless no_changes
        end
      end

      true
    end

    # If for whatever reason you need to unset all the cached
    # instance variables for refreshing data.
    #
    # @return [void]
    def clear_cache!
      @repos = nil
      @repo_paths = nil
      @all_repos = nil
      @my_repos = nil
      @org_teams = nil
      @team_repos = nil
      @team_members = nil
      @my_teams = nil
      @my_repo_names = nil

      true
    end

    private def get_client(octokit_params: OCTOKIT_PARAMS, &configuration)
      return @client if defined?(@client)

      Octokit.configure(&configuration) if block_given?

      # Lazy for now, will fix later
      @client = if octokit_params == OCTOKIT_PARAMS
        Octokit::Client.new(netrc: true).tap(&:login)
      else
        Octokit::Client.new(**octokit_params)
      end
    end
  end
end
