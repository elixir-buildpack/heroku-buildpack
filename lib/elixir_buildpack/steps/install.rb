require_relative '../helper'
require_relative '../utils'
require 'fileutils'

class ElixirBuildpack::Install
  include ElixirBuildpack::Utils
  include ElixirBuildpack::Helper

  def self.run
    new(
      build_dir: ElixirBuildpack::Main.build_dir,
      cache_dir: ElixirBuildpack::Main.cache_dir,
      env_dir: ElixirBuildpack::Main.env_dir
    ).run
  end

  def initialize(build_dir:, cache_dir:, env_dir:)
    @build_dir = build_dir
    @cache_dir = cache_dir
    @env_dir = env_dir
    @platform_dir = File.join(@build_dir, '.platform-tools')
  end

  def run
    logger.info('Installing OTP and Elixir')
    mkdir(@platform_dir)
    install_otp
    install_elixir
    setup_rebar
    setup_hex
    install_profile_script
  end

  private

  def install_otp
    logger.debug('Installing OTP')
    otp_dir = File.join(@platform_dir, 'otp')

    cpdir(File.join(@cache_dir, 'otp'), otp_dir)
    command("#{File.join(otp_dir, 'Install')} -minimal #{otp_dir}")
    prepend_path(File.join(otp_dir, 'bin'))
  end

  def install_elixir
    logger.debug('Installing Elixir')

    elixir_dir = File.join(@platform_dir, 'elixir')
    bin = File.join(elixir_dir, 'bin')

    cpdir(File.join(@cache_dir, 'elixir'), elixir_dir)
    FileUtils.chmod('+x', Dir[File.join(bin, '*')])
    prepend_path(bin)
  end

  def setup_rebar
    logger.debug('Setting up Rebar')
    command_in_build('mix local.rebar --force')
  end

  def setup_hex
    logger.debug('Setting up Hex')
    command_in_build('mix local.hex --force')
  end

  def install_profile_script
    logger.debug('Installing profile script')

    profile_dir = File.join(@build_dir, '.profile.d')
    profile_file = File.join(profile_dir, 'elixir-buildpack.sh')
    export_file = File.join(@build_dir, 'export')

    mkdir(profile_dir)
    File.open(profile_file, 'w') do |file|
      file.truncate(0)
      file.write(profile_script)
    end
    File.open(export_file, 'a') do |file|
      file.write("\n")
      file.write(profile_script)
    end
  end

  def profile_script
    lines = []

    add_paths = [
      '$HOME/.platform-tools/otp/bin',
      '$HOME/.platform-tools/elixir/bin'
    ]
    lines.push("export PATH=#{add_paths.append('$PATH').join(':')}")

    export_env = {}
    export_env['LC_CTYPE'] = '${LC_CTYPE:-en_US.utf8}'
    export_env['MIX_ENV'] = '${MIX_ENV:-prod}'
    lines.push(*export_env.map { |var, val| "export #{var}=#{val}" })

    lines.join("\n")
  end
end
