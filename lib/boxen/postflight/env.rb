require "boxen/postflight"

class Boxen::Postflight::Env < Boxen::Postflight

  # Calculate an MD5 checksum for the current environment.

  def self.checksum

    # We can't get this from config 'cause it's static (gotta happen
    # on load), and BOXEN_HOME might not be set.

    home = ENV["BOXEN_HOME"] || "/opt/boxen"
    return unless File.file? "#{home}/env.sh"
  if RUBY_PLATFORM =~ /Darwin/
    `find #{home}/env* -type f 2>&1 | sort | xargs /sbin/md5 | /sbin/md5 -q`.strip
  elsif RUBY_PLATFORM =~ /Debian/
    #TODO: figure out linux equivalent of above darwin line. maybe:
    `find #{home}/env* -type f 2>&1 | sort | xargs /usr/bin/md5sum | /usr/bin/md5sum --quiet`.strip
  end
    
  end

  # The checksum when this file was loaded.

  CHECKSUM = self.checksum

  def ok?
    self.class.checksum == CHECKSUM
  end

  def run
    warn "Source #{config.envfile} or restart your shell for new stuff!"
  end
end
