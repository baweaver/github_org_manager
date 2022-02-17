# frozen_string_literal: true

require_relative "github_org_manager/version"

require "octokit"
require "netrc"

module GithubOrgManager
  class Manager
    # Where your development files are stored
    DEV_HOME = File.join(Dir.home, "dev")

    # Default login params for Octokit, currently
    # relies on OAuth tokens in `~/.netrc`:
    #
    # ( https://github.com/octokit/octokit.rb#using-a-netrc-file )
    OCTOKIT_PARAMS = { netrc: true }

    attr_reader :dev_home, :org_name, :repos, :repo_paths

    # Creates a new Manager
    #
    # @param org_name: [String]
    #   Organization to pull data from
    #
    # @param dev_home: [String]
    #   Where development files and repos live on your machine
    #
    # @param octokit_params [Hash<Symbol, Any>]
    #   Params passed through to Octokit::Client constructor
    #
    # @param &octokit_configuration [Proc]
    #   Configuration block passed to Octokit.configure
    def initialize(
      org_name:,
      dev_home: DEV_HOME,
      octokit_params: OCTOKIT_PARAMS,
      &octokit_configuration
    )
      path_name = Pathname.new(dev_home)
      File.directory?(path_name) or raise "Directory does not exist: #{path_name}"

      @dev_home = path_name
      @org_name = org_name
      @org_path = File.join(path_name, org_name)

      @client = client(octokit_params:, &octokit_configuration)

      @repos = @client.org_repos(@org_name).to_h do |repo_data|
        [repo_data[:name], repo_data[:html_url]]
      end

      @repo_paths = @repos.to_h do |repo_name, _repo_url|
        [repo_name, File.join(@org_path, repo_name)]
      end
    end

    # Make sure that every repo in the organization exists on this
    # machine.
    def ensure_repo_directories_exist!
      Dir.mkdir(@org_path) unless Dir.exist?(@org_path)

      Dir.chdir(@org_path) do
        @repos.each do |name, html_url|
          `git clone "#{html_url}"` unless Dir.exist?(@repo_paths[name])
        end
      end

      true
    end

    # Update all repos
    def update_repos!
      # Hard to update repos which don't exist on the computer, make sure that
      # we have them all already downloaded, or do so
      ensure_repo_directories_exist!

      puts "📦 Updating #{@repo_paths.size} repos: \n"

      @repo_paths.each do |name, path|
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

    def client(octokit_params:, &configuration)
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
