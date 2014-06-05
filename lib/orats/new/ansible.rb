module Orats
  module New
    module Ansible
      def ansible_init(path)
        log_thor_task 'shell', 'Creating ansible inventory'
        run "mkdir #{path}/inventory"
        run "mkdir #{path}/inventory/group_vars"
        copy_from_includes 'inventory/hosts', path
        copy_from_includes 'inventory/group_vars/all.yml', path

        secrets_path = "#{path}/secrets"
        log_thor_task 'shell', 'Creating ansible secrets'
        run "mkdir #{secrets_path}"

        save_secret_string "#{secrets_path}/postgres_password"

        if @options[:redis_password].empty?
          run "touch #{secrets_path}/redis_password"
        else
          save_secret_string "#{secrets_path}/redis_password"
          gsub_file "#{path}/inventory/group_vars/all.yml", 'redis_password: false', 'redis_password: true'
        end

        save_secret_string "#{secrets_path}/mail_password"
        save_secret_string "#{secrets_path}/rails_token"
        save_secret_string "#{secrets_path}/devise_token"
        save_secret_string "#{secrets_path}/devise_pepper_token"

        log_thor_task 'shell', 'Modifying secrets path in group_vars/all.yml'
        gsub_file "#{path}/inventory/group_vars/all.yml", '~/tmp/testproj/secrets/', File.expand_path(secrets_path)

        log_thor_task 'shell', 'Modifying the place holder app name in group_vars/all.yml'
        gsub_file "#{path}/inventory/group_vars/all.yml", 'testproj', File.basename(path)

        log_thor_task 'shell', 'Creating ssh keypair'
        run "ssh-keygen -t rsa -P '' -f #{secrets_path}/id_rsa"

        log_thor_task 'shell', 'Creating self signed ssl certificates'
        run create_rsa_certificate(secrets_path, 'sslkey.key', 'sslcert.crt')

        log_thor_task 'shell', 'Creating monit pem file'
        run "#{create_rsa_certificate(secrets_path, 'monit.pem', 'monit.pem')} && openssl gendh 512 >> #{secrets_path}/monit.pem"

        install_role_dependencies unless @options[:skip_galaxy]
      end

      private

      def copy_from_includes(file, destination_root_path)
        base_path = "#{File.expand_path File.dirname(__FILE__)}/../templates/includes"

        log_thor_task 'shell', "Creating #{file}"
        run "cp #{base_path}/#{file} #{destination_root_path}/#{file}"
      end

      def save_secret_string(file)
        File.open(file, 'w+') { |f| f.write(SecureRandom.hex(64)) }
      end

      def create_rsa_certificate(secrets_path, keyout, out)
        "openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj '/C=US/ST=Foo/L=Bar/O=Baz/CN=qux.com' -keyout #{secrets_path}/#{keyout} -out #{secrets_path}/#{out}"
      end

      def install_role_dependencies
        log_thor_task 'shell', 'Updating ansible roles from the galaxy'

        galaxy_install = "ansible-galaxy install -r #{galaxy_file_path} --force"
        galaxy_out = run(galaxy_install, capture: true)

        if galaxy_out.include?('you do not have permission')
          if @options[:sudo_password].empty?
            sudo_galaxy_command = 'sudo'
          else
            sudo_galaxy_command = "echo #{@options[:sudo_password]} | sudo -S"
          end

          run("#{sudo_galaxy_command} #{galaxy_install}")
        end
      end
    end
  end
end