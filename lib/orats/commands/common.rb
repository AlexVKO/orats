require 'orats/commands/ui'
require 'orats/commands/outdated/parse'

module Orats
  module Commands
    class Common
      include Thor::Base
      include Thor::Shell
      include Thor::Actions
      include UI
      include Outdated::Parse

      RELATIVE_PATHS = {
          galaxyfile: 'templates/includes/Galaxyfile',
          hosts: 'templates/includes/inventory/hosts',
          inventory: 'templates/includes/inventory/group_vars/all.yml',
          playbook: 'templates/play.rb',
          version: 'version.rb'
      }

      attr_accessor :remote_gem_version, :remote_paths, :local_paths

      def initialize(target_path = '', options = {})
        @target_path = target_path
        @options = options
        @active_path = @target_path

        @local_paths = {}
        @remote_paths = {}

        build_common_paths

        self.destination_root = Dir.pwd
        @behavior = :invoke
      end

      private

      def base_path
        File.join(File.expand_path(File.dirname(__FILE__)), '..')
      end

      def repo_path
        %w(https://raw.githubusercontent.com/nickjj/orats lib/orats)
      end

      def select_branch(branch, value)
        "#{repo_path[0]}/#{branch}/#{repo_path[1]}/#{value}"
      end

      def build_common_paths
        @remote_paths[:version] = select_branch 'master', RELATIVE_PATHS[:version]
        @remote_gem_version = gem_version

        RELATIVE_PATHS.each_pair do |key, value|
          @local_paths[key] = "#{base_path}/#{value}"
          @remote_paths[key] = select_branch @remote_gem_version, value
        end
      end

      def url_to_string(url)
        begin
          open(url).read
        rescue *[OpenURI::HTTPError, SocketError] => ex
          log_error 'error', "Error accessing URL #{url}",
                    'message', ex
          exit 1
        end
      end

      def file_to_string(path)
        if File.exist?(path) && File.file?(path)
          IO.read(path)
        else
          log_error 'error', 'Error finding file',
                    'message', path
          exit 1
        end
      end

      def exit_if_path_exists
        log_task 'Check if this path exists'

        if Dir.exist?(@active_path) || File.exist?(@active_path)
          log_error 'error', 'A file or directory already exists at this location', 'path', @active_path
          exit 1
        end
      end

      def exit_if_cannot_access(process, tip)
        log_task "Check for #{process}"

        exit 1 if process_unusable?("which #{process}", process, 'on your path', tip)
      end

      def exit_if_process_not_running(*processes)
        processes.each do |process|
          log_task "Check if #{process} is running"

          exit 1 if process_unusable?("ps cax | grep #{process}", process,
                                      'running', "#{process} must be running before running this orats command")
        end
      end

      def process_unusable?(command, process, question_suffix, tip)
        command_output = run(command, capture: true)

        log_error 'error', "Cannot detect #{process}", 'question', "Are you sure #{process} is #{question_suffix}?", true do
          log_status_bottom 'tip', tip, :white
        end if command_output.empty?

        command_output.empty?
      end
    end
  end
end