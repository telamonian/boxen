require "boxen/preflight"

class Boxen::Preflight::OS < Boxen::Preflight
  SUPPORTED_RELEASES = %w(10.8 10.9)

  def ok?
    (linux? || (osx? && supported_release?))
  end

  def run
    abort "You must be running one of the following OS X versions: #{SUPPORTED_RELEASES.join(' ')}."
  end

  private

  def osx?
    `uname -s`.chomp == "Darwin"
  end

  def linux?
    `uname -s`.chomp == "Linux"
  end

  def supported_release?
    SUPPORTED_RELEASES.any? do |r|
      current_release.start_with? r
    end
  end

  def current_release
    @current_release ||= `sw_vers -productVersion`
  end
end
