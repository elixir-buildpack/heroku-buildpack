require_relative '../helper'
require_relative '../utils'
require 'yaml'

class ElixirBuildpack::Config
  include ElixirBuildpack::Helper
  include ElixirBuildpack::Utils

  LAST_RUN_FILE = 'last-run.yml'.freeze
  CONFIG_FILE = '.elixir-buildpack.yml'.freeze
  LEGACY_CONFIG_FILE = 'elixir_buildpack.config'.freeze
  LEGACY_CONFIG_REGEX = /^([a-z_]+)=(.+)$/.freeze

  EXCLUDED_ENV = %w[
    PATH
    GIT_DIR
    CPATH
    CPPATH
    LD_PRELOAD
    LIBRARY_PATH
  ].freeze

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
    :disable_cache

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
    load
  end

  private

  def load
    logger.info('Configuring Elixir buildpack')

    if File.exist?(File.join(@build_dir, CONFIG_FILE))
      logger.debug('Using config from app')
      load_config
    elsif File.exist?(File.join(@build_dir, LEGACY_CONFIG_FILE))
      logger.warn('Using a legacy config')
      load_legacy_config
    else
      logger.warn('Using default config')
    end

    default_config
    load_last_versions
    set_stack
    load_environment_variables
  end

  def default_config
    @otp_version ||= '23.3.1'
    @elixir_version ||= '1.11.4'
    @disable_build_cache ||= false
    @release ||= false
    @disable_cache ||= false
    @pre_compile_command ||= ''
    @compile_command ||= ''
    @post_compile_command ||= ''
  end

  def load_config
    config = YAML.load_file(File.join(@build_dir, CONFIG_FILE))
    exit_with_error('Invalid buildpack config') unless config.is_a?(Hash)

    config = config.
             transform_values(&:to_s).
             transform_values(&:strip).
             reject { |_k, v| v.empty? }

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
    config = File.readlines(File.join(@build_dir, LEGACY_CONFIG_FILE)).
             map { |line| line.strip.match(LEGACY_CONFIG_REGEX) }.
             compact.
             map { |match| [match[0].strip, match[1].strip] }.
             to_h

    @otp_version = config['erlang_version']
    @elixir_version = config['elixir_version']
    @disable_build_cache = config['always_rebuild'] == 'true'
    @release = config['release'] == 'true'
    @pre_compile_command = config['hook_pre_compile']
    @compile_command = config['hook_compile']
    @post_compile_command = config['hook_post_compile']
  end

  def load_last_versions
    file = File.join(@cache_dir, LAST_RUN_FILE)
    if File.exist?(file)
      last_versions = YAML.load_file(file)

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

  def load_environment_variables
    logger.debug('Loading environment variables')
    loaded_env = Dir[File.join(@env_dir, '*')].map do |env_file|
                   exit_with_error("#{env_file} is not a file") unless File.file?(env_file)
                   [File.basename(env_file), File.read(env_file)]
                 end.reject { |pair| EXCLUDED_ENV.include?(pair.first) }.to_h

    @env = ENV.to_h.merge(loaded_env)

    @env['MIX_ENV'] ||= 'prod'
  end
end
