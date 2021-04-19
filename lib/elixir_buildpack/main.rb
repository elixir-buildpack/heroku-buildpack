require 'singleton'
require 'forwardable'
require 'logger'
require 'yaml'

require_relative 'utils'
require_relative 'helper'

Dir.
  entries(File.join(__dir__, 'steps')).
  reject { |entry| entry =~ /^\./ }.
  map { |file| File.basename(file, '.rb') }.
  each { |file| require_relative "steps/#{file}" }

class ElixirBuildpack::Main
  extend SingleForwardable
  include Singleton
  include ElixirBuildpack::Utils

  attr_reader :logger, :config
  attr_accessor :build_dir, :cache_dir, :env_dir

  def_delegators :instance, :detect, :compile, :release

  def_delegators :instance, :config, :logger

  def_delegators :instance, :build_dir=, :build_dir
  def_delegators :instance, :cache_dir=, :cache_dir
  def_delegators :instance, :env_dir=, :env_dir

  def initialize
    setup_logger
  end

  def detect
    if is_elixir
      print("Elixir\n")
    else
      exit_with_error('Elixir not detected')
    end
  end

  def compile
    exit_with_error('Elixir not detected') unless is_elixir

    [@build_dir, @cache_dir, @env_dir].each do |dir|
      exit_with_error("#{dir} is a file") if File.file?(dir)
      exit_with_error("#{dir} does not exist") unless Dir.exist?(dir)
    end

    @cache_dir = File.join(@cache_dir, 'elixir-buildpack')
    mkdir(@cache_dir)
    @config = ElixirBuildpack::Config.load

    ElixirBuildpack::Caching.setup
    ElixirBuildpack::Download.run
    ElixirBuildpack::Install.run
    ElixirBuildpack::Compile.run
    ElixirBuildpack::Caching.teardown

    @logger.info('Successfully built Elixir app')
  end

  def release
    print(
      {
        'addons' => [],
        'default_process_types' => {
          'web' => 'mix run --no-halt'
        }
      }.to_yaml
    )
  end

  private

  def is_elixir
    Dir.exist?(@build_dir) && File.exist?(File.join(@build_dir, 'mix.exs'))
  end

  def setup_logger
    @logger = Logger.new(STDOUT)

    @logger.formatter = proc do |severity, _datetime, _progname, msg|
      case severity
      when 'DEBUG'
        "       #{msg}\n"
      when 'WARN'
        "       #{msg} <----------- Warning!\n"
      when 'ERROR'
        "       #{msg} <----------- Error!\n"
      when 'FATAL'
        "#{severity}: #{msg}\n"
      else
        "-----> #{msg}\n"
      end
    end
  end
end
