require_relative '../helper'
require_relative '../utils'
require 'yaml'

class ElixirBuildpack::Config
  include ElixirBuildpack::Helper
  include ElixirBuildpack::Utils

  LAST_RUN_FILE = 'last-run.yml'.freeze

  DEFAULT_CONFIG_FILE = '../../../.elixir-buildpack.yml'.freeze
  DEFAULT_CONFIG_VALUE = ''.freeze
  APP_CONFIG_FILE = '.elixir-buildpack.yml'.freeze

  LEGACY_CONFIG_FILE = 'elixir_buildpack.config'.freeze
  LEGACY_CONFIG_REGEX = /^([a-z_]+)=(.+)$/.freeze

  ENV_REGEX = /\A([^=]+)=(.+)\z/.freeze

  IGNORED_APP_ENV = %w[
    PATH
    GIT_DIR
    CPATH
    CPPATH
    LD_PRELOAD
    LIBRARY_PATH
  ].freeze

  DEFAULT_ENV = {
    'MIX_ENV' => 'prod',
    'LC_CTYPE' => 'en_US.utf8'
  }.freeze

  attr_reader :otp_version,
    :elixir_version,
    :env,
    :stack,
    :last_otp_version,
    :last_elixir_version,
    :disable_build_cache,
    :release,
    :pre_compile_command,
    :compile_command,
    :post_compile_command,
    :disable_cache,
    :legacy_compatability

  def self.load
    new(
      build_dir: ElixirBuildpack::Main.build_dir,
      cache_dir: ElixirBuildpack::Main.cache_dir,
      env_dir: ElixirBuildpack::Main.env_dir
    )
  end

  def initialize(build_dir:, cache_dir:, env_dir:)
    @build_dir = build_dir
    @cache_dir = cache_dir
    @env_dir = env_dir
    @env = ENV.to_h
    @legacy_compatability = false

    logger.info('Configuring the Elixir buildpack')
    load_config

    if @otp_version.to_s.empty? || @elixir_version.to_s.empty?
      exit_with_error('The OTP and Elixir versions need to be set if a config file is used!')
    else
      logger.debug("Using OTP: #{@otp_version}")
      logger.debug("Using Elixir: #{@elixir_version}")
    end

    load_last_versions
    set_stack
    load_exported_environment
    load_user_environment
    load_default_environment
  end

  private

  def load_config
    if File.exist?(File.join(@build_dir, APP_CONFIG_FILE))
      logger.debug('Using config from app')
      load_app_config
    elsif File.exist?(File.join(@build_dir, LEGACY_CONFIG_FILE))
      logger.warn('Using a legacy config')
      load_legacy_config
      @legacy_compatability = true
    else
      logger.warn('Using default config')
      load_default_config
    end
  end

  def load_default_config
    default_config_file = File.expand_path(File.join(__dir__, DEFAULT_CONFIG_FILE))
    load_config_file(default_config_file)
  end

  def load_app_config
    load_config_file(File.join(@build_dir, APP_CONFIG_FILE))
  end

  def new_hash
    Hash.new(DEFAULT_CONFIG_VALUE)
  end

  def load_config_file(file)
    loaded_config = YAML.load_file(file)
    exit_with_error('Invalid buildpack config') unless loaded_config.is_a?(Hash)

    cleaned_config = loaded_config.
                     transform_values(&:to_s).
                     transform_values(&:strip).
                     reject { |_k, v| v.empty? }

    config = new_hash.merge(cleaned_config)

    @otp_version = config['otp_version']
    @elixir_version = config['elixir_version']
    @disable_build_cache = config['disable_build_cache'] == 'true'
    @release = config['release'] == 'true'
    @pre_compile_command = config['pre_compile_command']
    @compile_command = config['compile_command']
    @post_compile_command = config['post_compile_command']
    @disable_cache = config['disable_cache'] == 'true'
  end

  def load_legacy_config
    config = new_hash.merge(
      File.readlines(File.join(@build_dir, LEGACY_CONFIG_FILE)).
      map { |line| line.strip.match(LEGACY_CONFIG_REGEX) }.
      compact.
      map { |match| [match[1].strip, match[2].strip] }.
      to_h
    )

    @otp_version = config['erlang_version']
    @elixir_version = config['elixir_version']
    @disable_build_cache = config['always_rebuild'] == 'true'
    @release = config['release'] == 'true'
    @pre_compile_command = config['hook_pre_compile']
    @compile_command = config['hook_compile']
    @post_compile_command = config['hook_post_compile']
  end

  def load_last_versions
    last_run_file = File.join(@cache_dir, LAST_RUN_FILE)

    if File.exist?(last_run_file)
      logger.debug('Loading version information from last build')
      last_versions = YAML.load_file(last_run_file).transform_values(&:to_s)

      @last_otp_version = last_versions['otp_version']
      @last_elixir_version = last_versions['elixir_version']
    else
      @last_otp_version = ''
      @last_elixir_version = ''
    end
  end

  def set_stack
    @stack = ENV['STACK']
    exit_with_error('STACK environment variable is not set') if @stack.nil?
    logger.debug("Using stack: #{@stack}")
  end

  def load_exported_environment
    buildpack_export = File.join(@build_dir, 'export')

    if File.exist?(buildpack_export) && !File.file?(buildpack_export)
      logger.warn('There is a folder named export in the app directory, this can cause issues if using multiple buildpacks!')
      return
    elsif !File.exist?(buildpack_export)
      return
    end

    logger.debug('Loading environment from previous buildpack')

    exported_env = command_in_build(". #{buildpack_export} >/dev/null 2>&1 && env", @env).
                   split("\n").
                   map { |line| line.match(ENV_REGEX) }.
                   compact.
                   map { |match| [match[1], match[2]] }.
                   to_h

    @env = exported_env
  end

  def load_user_environment
    logger.debug('Loading environment variables')

    loaded_env = Dir[File.join(@env_dir, '*')].map do |env_file|
                   exit_with_error("#{env_file} is not a file") unless File.file?(env_file)
                   [File.basename(env_file), File.read(env_file)]
                 end.reject { |pair| IGNORED_APP_ENV.include?(pair.first) }.to_h

    @env = @env.merge(loaded_env)
  end

  def load_default_environment
    logger.debug('Setting default buildpack environment variables')
    @env = new_hash.merge(DEFAULT_ENV).merge(@env)
  end
end
