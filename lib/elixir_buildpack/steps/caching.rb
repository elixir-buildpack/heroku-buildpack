require_relative '../helper'
require_relative '../utils'
require 'yaml'

class ElixirBuildpack::Caching
  include ElixirBuildpack::Helper
  include ElixirBuildpack::Utils

  class << self
    def setup
      default.setup
    end

    def teardown
      default.teardown
    end

    private

    def default
      new(
        build_dir: ElixirBuildpack::Main.build_dir,
        cache_dir: ElixirBuildpack::Main.cache_dir
      )
    end
  end

  def initialize(build_dir:, cache_dir:)
    @build_dir = build_dir
    @cache_dir = cache_dir

    @otp_changed = config.last_otp_version != config.otp_version
    @elixir_changed = config.last_elixir_version != config.elixir_version
  end

  def setup
    logger.info('Setting up caching')
    if config.disable_cache
      logger.warn('Disabling cache and deleting existing cache')
      mkdir(@cache_dir, true)
    else
      logger.debug('Restoring buildpack cache')
      mkdir(@cache_dir)
      restore_otp_cache
      restore_elixir_cache
      restore_mix_caches
      restore_dep_cache
      restore_build_cache
    end
  end

  def teardown
    logger.info('Save build to cache')
    if config.disable_cache
      logger.warn('Skipping caching step and clearing existing cache')
      rmdir(@cache_dir)
    else
      cache_hex
      cache_deps
      cache_build
      cache_version_info
    end
  end

  private

  def restore_otp_cache
    return unless @otp_changed

    logger.debug('OTP version changed, clearing cache')
    rmdir(File.join(@cache_dir, 'otp'))
  end

  def restore_elixir_cache
    return unless @otp_changed || @elixir_changed

    logger.debug('Elixir version changed, clearing cache')
    rmdir(File.join(@cache_dir, 'elixir'))
  end

  def restore_mix_caches
    logger.debug('Restoring mix and hex caches')

    dirs = {}
    dirs[File.join(@cache_dir, 'mix')] = File.join(@build_dir, '.mix')
    dirs[File.join(@cache_dir, 'hex')] = File.join(@build_dir, '.hex')

    dirs.each do |cache_dir, dest_dir|
      if Dir.exist?(cache_dir)
        cpdir(cache_dir, dest_dir)
      else
        mkdir(dest_dir, true)
      end
    end
  end

  def restore_dep_cache
    dep_cache_dir = File.join(@cache_dir, 'deps')
    cpdir(dep_cache_dir, File.join(@build_dir, 'deps')) if Dir.exist?(dep_cache_dir)
  end

  def restore_build_cache
    build_cache_dir = File.join(@cache_dir, 'build')
    if (@otp_changed || @elixir_changed) && Dir.exist?(build_cache_dir)
      rmdir(build_cache_dir)
    elsif config.disable_build_cache
      logger.debug('Skipping build cache')
      rmdir(build_cache_dir)
    elsif Dir.exist?(build_cache_dir)
      cpdir(build_cache_dir, File.join(@build_dir, '_build'))
    end
  end

  def cache_hex
    logger.debug('Saving Mix and Hex cache')
    cpdir(File.join(@build_dir, '.mix'), File.join(@cache_dir, 'mix'))
    cpdir(File.join(@build_dir, '.hex'), File.join(@cache_dir, 'hex'))
  end

  def cache_deps
    logger.debug('Saving app dependencies')
    cpdir(File.join(@build_dir, 'deps'), File.join(@cache_dir, 'deps'))
  end

  def cache_build
    return logger.debug('Skipping build cache') if config.disable_build_cache

    logger.debug('Saving app build cache')
    cpdir(File.join(@build_dir, '_build'), File.join(@cache_dir, 'build'))
  end

  def cache_version_info
    logger.debug('Saving OTP and Elixir versions to cache')
    File.open(File.join(@cache_dir, 'last-run.yml'), 'w') do |file|
      file.truncate(0)
      file.write(
        {
          'otp_version' => config.otp_version,
          'elixir_version' => config.elixir_version
        }.to_yaml
      )
    end
  end
end
