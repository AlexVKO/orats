require 'securerandom'

module Orats
  module Shell
    def run_from(path, command)
      run "cd #{path} && #{command} && cd -"
    end

    def log_message(type, message)
      puts
      say_status  type, "#{message}...", :yellow
      puts        '-'*80, ''; sleep 0.25
    end

    def git_commit(message)
      run_from @active_path, "git add . && git commit -m '#{message}'"
    end

    def gsub_postgres_info
      log_message 'root', 'Changing the postgres information'

      gsub_file "#{@active_path}/.env", ': localhost', ": #{@options[:pg_location]}"
      gsub_file "#{@active_path}/.env", ': postgres', ": #{@options[:pg_username]}"
      gsub_file "#{@active_path}/.env", ': supersecrets', ": #{@options[:pg_password]}"
    end

    def gsub_redis_info
      log_message 'root', 'Adding the redis password'

      gsub_file "#{@active_path}/config/initializers/sidekiq.rb", '//', '//:#{ENV[\'TESTPROJ_CACHE_PASSWORD\']}@'
      gsub_file "#{@active_path}/.env", ': greatsecurity', ": #{@options[:redis_password]}"
    end

    def gsub_project_path
      log_message 'root', 'Changing the project path'

      gsub_file "#{@active_path}/.env", ': /full/path/to/your/project', ": #{File.expand_path(@active_path)}"
    end

    def run_rake(command)
      log_message 'shell', 'Running rake commands'

      run_from @active_path, "bundle exec rake #{command}"
    end

    def bundle_install
      log_message 'shell', 'Running bundle install, this may take a while'

      run_from @active_path, 'bundle install'
    end

    def bundle_binstubs
      log_message 'shell', 'Running bundle binstubs for a few gems'

      run_from @active_path, 'bundle binstubs whenever puma sidekiq'
    end

    def spring_binstub
      log_message 'shell', 'Running spring binstub'

      run_from @active_path, 'bundle exec spring binstub --all'
    end

    def nuke_warning
      puts
      say_status  'nuke', "\e[1mYou are about to permanently delete this directory:\e[0m", :red
      say_status  'path', "#{File.expand_path(@app_name)}", :yellow
      puts
    end

    def rails_directories
      rails_gemfiles = run("find #{@active_path} -type f -name Gemfile | xargs grep -lE \"gem 'rails'|gem \\\"rails\\\"\"", capture: true)
      gemfile_paths = rails_gemfiles.split("\n")

      gemfile_paths.map { |gemfile| File.dirname(gemfile) }
    end

    def nuke_data_details_warning
      rails_projects = []

      rails_directories.each do |rails_dir|
        rails_projects << File.basename(rails_dir)
      end

      project_names = rails_projects.join(', ')

      puts
      say_status  'nuke', "\e[1mYou are about to permanently delete all postgres databases for:\e[0m", :red
      say_status  'databases', project_names, :yellow
      puts
      say_status  'nuke', "\e[1mYou are about to permanently delete all redis namespaces for:\e[0m", :red
      say_status  'namespace', project_names, :yellow
      puts
    end

    def nuke_data
      rails_directories.each do |directory|
        log_message 'root', 'Removing postgres databases'
        run_from directory, 'bundle exec rake db:drop:all'
        nuke_redis File.basename(directory)
      end
    end

    def can_play?
      log_message 'shell', 'Checking for the ansible binary'

       has_ansible = run('which ansible', capture: true)

       dependency_error 'Cannot access ansible',
                        'Are you sure you have ansible setup correctly?',
                        'http://docs.ansible.com/intro_installation.html`' if has_ansible.empty?

       !has_ansible.empty?
    end

    def rails_template(command, flags = '')
      exit_if_cannot_rails
      exit_if_exists unless flags.index(/--skip/)

      run "rails new #{@active_path} #{flags} --skip-bundle --template #{File.expand_path File.dirname(__FILE__)}/templates/#{command}.rb"
      yield if block_given?
    end

    def play_app(path)
      return unless can_play?

      @active_path = path
      rails_template 'play'
    end

    def ansible_init(path)
      log_message 'shell', 'Creating ansible inventory'
      run "mkdir #{path}/inventory"
      run "mkdir #{path}/inventory/group_vars"
      copy_from_includes 'inventory/hosts', path
      copy_from_includes 'inventory/group_vars/all.yml', path

      secrets_path = "#{path}/secrets"
      log_message 'shell', 'Creating ansible secrets'
      run "mkdir #{secrets_path}"

      save_secret_string "#{secrets_path}/postgres_password"
      save_secret_string "#{secrets_path}/redis_password"
      save_secret_string "#{secrets_path}/mail_password"
      save_secret_string "#{secrets_path}/rails_token"
      save_secret_string "#{secrets_path}/devise_token"
      save_secret_string "#{secrets_path}/devise_pepper_token"

      log_message 'shell', 'Modifying secrets path in group_vars/all.yml'
      update_secrets_path secrets_path

      log_message 'shell', 'Creating ssh keypair'
      run "echo '' | echo '' | echo #{secrets_path}/id_rsa | ssh-keygen -t rsa"

      log_message 'shell', 'Creating self signed ssl certificates'
      # these are very insecure as I'm not generating new keys for everyone, this should only be used to test
      # SSL on your web app before switching to signed keys from a trusted vendor
      copy_from_includes 'secrets/sslcert.crt', path
      copy_from_includes 'secrets/sslkey.key', path
    end

    private

      def save_secret_string(file)
        File.open(file, 'w+') { |f| f.write(SecureRandom.hex(64)) }
      end

      def update_secrets_path(secrets_path)
        all_yaml_path = "#{secrets_path}/../inventory/group_vars/all.yml"

        IO.write(all_yaml_path, File.open(all_yaml_path) do |f|
          f.read.gsub('~/tmp/testproj/secrets/', secrets_path)
        end
        )
      end

      def copy_from_includes(file, destination_root_path)
        base_path = "#{File.expand_path File.dirname(__FILE__)}/templates/includes"

        log_message 'shell', "Creating #{file}"
        run "cp #{base_path}/#{file} #{destination_root_path}/#{file}"
      end

      def nuke_redis(namespace)
        log_message 'root', 'Removing redis keys'

        run "redis-cli KEYS '#{namespace}:*' | xargs --delim='\n' redis-cli DEL"
      end

      def nuke_directory
        log_message 'root', 'Deleting directory'

        run "rm -rf #{@active_path}"
      end

      def dependency_error(message, question, answer)
        puts
        say_status  'error', "\e[1m#{message}\e[0m", :red
        say_status  'question', question, :yellow
        say_status  'answer', answer, :cyan
        puts        '-'*80
        puts
      end

      def exit_if_cannot_rails
        log_message 'shell', 'Checking for rails'

        has_rails = run('which rails', capture: true)

        dependency_error 'Cannot access rails',
                         'Are you sure you have rails setup correctly?',
                         'You can install it by running `gem install rails`' if has_rails.empty?

        exit 1 if has_rails.empty?
      end

      def exit_if_exists
        log_message 'shell', 'Checking if a file or directory already exists'

        if Dir.exist?(@active_path) || File.exist?(@active_path)
          puts
          say_status  'aborting', "\e[1mA file or directory already exists at this location:\e[0m", :red
          say_status  'location', @active_path, :yellow
          puts        '-'*80
          puts

          exit 1
        end
      end
  end
end