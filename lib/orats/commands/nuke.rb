require 'orats/commands/common'

module Orats
  module Commands
    class Nuke < Common
      def initialize(target_path = '', options = {})
        super
      end

      def init
        log_nuke_info
        log_nuke_details unless @options[:skip_data]

        confirmed_to_delete = yes?('Are you sure? (y/N)', :cyan); puts

        if confirmed_to_delete
          nuke_data unless @options[:skip_data]
          nuke_directory
        end
      end

      private

      def log_nuke_info
        log_error 'nuke', 'You are about to permanently delete this directory',
                  'path', File.expand_path(@target_path)
      end

      def log_nuke_details
        rails_projects = []

        valid_rails_directories.each { |rails_dir| rails_projects << File.basename(rails_dir) }
        project_names = rails_projects.join(', ')

        log_error 'nuke', 'You are about to permanently delete all postgres databases for',
                  'databases', project_names, true

        log_error 'nuke', 'You are about to permanently delete all redis namespaces for',
                  'namespaces', project_names
      end

      def valid_rails_directories
        rails_gemfiles =
            run("find #{@active_path} -type f -name Gemfile | xargs grep -lE \"gem 'rails'|gem \\\"rails\\\"\"",
                capture: true)

        gemfile_paths = rails_gemfiles.split("\n")

        gemfile_paths.map { |gemfile| File.dirname(gemfile) }
      end

      def nuke_data
        valid_rails_directories.each do |directory|
          log_thor_task 'root', 'Removing postgres databases'
          run_from directory, 'bundle exec rake db:drop:all'

          nuke_redis File.basename(directory)
        end
      end

      def nuke_redis(namespace)
        log_thor_task 'root', 'Removing redis keys'
        run "redis-cli KEYS '#{namespace}:*' | xargs --delim='\n' redis-cli DEL"
      end

      def nuke_directory
        log_thor_task 'root', 'Deleting directory'
        run "rm -rf #{@active_path}"
      end
    end
  end
end