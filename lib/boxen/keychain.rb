require "etc"
require "shellwords"

module Boxen
  class Keychain

    # The keychain proxy we use to provide isolation and a friendly
    # message in security prompts.
    if (/darwin/ =~ RUBY_PLATFORM) != nil
      HELPER = File.expand_path "../../../script/Boxen", __FILE__
    else
      HELPER_ENV = File.expand_path "../../../script/keyring-env", __FILE__
      HELPER = File.expand_path "../../../script/Boxen-keyring", __FILE__
    end

    # The service name to use when loading/saving passwords.

    PASSWORD_SERVICE = "GitHub Password"

    # The service name to use when loading/saving API keys.

    TOKEN_SERVICE = "GitHub API Token"

    def initialize(login)
      @login = login
      # Clear the password. We're storing tokens now.
      set PASSWORD_SERVICE, ""
    end

    def token
      get TOKEN_SERVICE
    end

    def token=(token)
      set TOKEN_SERVICE, token
    end

    protected

    attr_reader :login

    def get(service)
      cmd = shellescape(HELPER, service, login)
      if (/darwin/ =~ RUBY_PLATFORM) != nil
        result = `#{cmd}`.strip
      else
        # have to run gnome-keyring commands as user, running as root causes error
        if ENV['USER'] == login
          result = `#{cmd}`.strip
        elsif ENV['USER'] == 'root'
          # dbus env variable has to be set in order to talk to gnome-keyring
          cmd_env = shellescape(HELPER_ENV)
          ENV['DBUS_SESSION_BUS_ADDRESS'] = `#{cmd_env}`.strip
          result = backticks_as_user(login, cmd).strip
        else
          raise Boxen::Error, "User id is set to #{ENV['USER']}, but have to be self or root in order to interact with the keyring."  
        end
      end
      $?.success? ? result : nil 
    end

    def set(service, token)
      cmd = shellescape(HELPER, service, login, token)
      if (/darwin/ =~ RUBY_PLATFORM) != nil
        unless system *cmd
          raise Boxen::Error, "Can't save #{service} in the keychain."
        end
      else
        # have to run gnome-keyring commands as user, running as root causes errors
        if ENV['USER'] == login
          result = system *cmd
        elsif ENV['USER'] == 'root'
          # dbus env variable has to be set in order to talk to gnome-keyring
          cmd_env = shellescape(HELPER_ENV)
          ENV['DBUS_SESSION_BUS_ADDRESS'] = `#{cmd_env}`.strip
          result = system_as_user(login, cmd)
        else
          raise Boxen::Error, "User id is set to #{ENV['USER']}, but have to be self or root in order to interact with the keyring."
        end
        unless result
          raise Boxen::Error, "Can't save #{service} in the keyring."
        end
      end

      token
    end

    def shellescape(*args)
      args.map { |s| Shellwords.shellescape s }.join " "
    end
    
    def system_as_user(user, cmd)
      # Find the user in the password database.
      u = (user.is_a? Integer) ? Etc.getpwuid(user) : Etc.getpwnam(user)

      # Fork the child process. Process.fork will run a set of tokens as a bash command
      # in the child process.
      Process.fork do
        # We're in the child. Set the process's user ID.
        #Process.uid = u.uid
        Process::Sys.setuid(u.uid)
        # Invoke the caller's bash tokens
        system *cmd
      end
      Process.wait
      $?.exitstatus
    end
    
    def backticks_as_user(user, cmd)
      u = (user.is_a? Integer) ? Etc.getpwuid(user) : Etc.getpwnam(user)

      # may the armpits of the ruby and gnome devs be infested with the fleas of a thousand camels!
      # all of the IO.pipe stuff is so that the parent and child forks can talk to each other
      rd, wr = IO.pipe
      Process.fork do
        rd.close
        Process::Sys.setuid(u.uid)
        result = `#{cmd}`
        wr.write result
        wr.close
      end
      wr.close
      result = rd.read
      rd.close
      Process.wait
      result
    end
  end
end
