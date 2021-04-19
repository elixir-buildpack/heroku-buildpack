require_relative '../helper'
require_relative '../utils'
require 'net/http'

class ElixirBuildpack::Download
  include ElixirBuildpack::Utils
  include ElixirBuildpack::Helper

  def self.run
    new(
      cache_dir: ElixirBuildpack::Main.cache_dir
    ).run
  end

  def initialize(cache_dir:)
    @cache_dir = cache_dir

    @otp_version = config.otp_version
    @elixir_version = config.elixir_version
    @stack = config.stack

    @download_dir = File.join(@cache_dir, 'download')
    @otp_dir = File.join(@cache_dir, 'otp')
    @elixir_dir = File.join(@cache_dir, 'elixir')
  end

  def run
    logger.info('Downloading OTP and Elixir')

    mkdir(File.join(@cache_dir, 'download'))
    set_files_and_urls
    download_otp_and_elixir
    clean_downloads
  end

  private

  def set_files_and_urls
    @otp_file = File.join(@download_dir, "otp-#{@otp_version}-#{@stack}.tar.gz")
    @elixir_file = File.join(@download_dir, "elixir-#{@elixir_version}-otp-#{short_otp_version}.zip")
    @otp_url = "https://github.com/elixir-buildpack/heroku-otp/releases/download/#{@otp_version}/#{@stack}.tar.gz"
    @elixir_url = "https://repo.hex.pm/builds/elixir/v#{@elixir_version}-otp-#{short_otp_version}.zip"
  end

  def short_otp_version
    config.otp_version.split('.').first
  end

  def download_otp_and_elixir
    if Dir.exist?(@otp_dir)
      logger.debug('Using cached OTP')
    else
      mkdir(@otp_dir)
      download_file('OTP', @otp_url, @otp_file)
      untar(@otp_file, @otp_dir)
    end

    if Dir.exist?(@elixir_dir)
      logger.debug('Using cached Elixir')
    else
      mkdir(@elixir_dir)
      download_file('Elixir', @elixir_url, @elixir_file)
      unzip(@elixir_file, @elixir_dir)
    end
  end

  def download_file(name, url, save_file)
    if File.exist?(save_file)
      logger.debug("Using cached #{name} download")
    else
      logger.debug("Downloading #{name}")
      fetch(url, save_file, name)
    end
  end

  def fetch(url, file, name, limit = 10)
    exit_with_error("Too many redirects while downloading #{name}") if limit == 0

    uri = URI.parse(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(Net::HTTP::Get.new(uri)) do |response|
        case response
        when Net::HTTPRedirection
          fetch(response['location'], file, name, limit - 1)
        when Net::HTTPSuccess
          File.open(file, 'wb') do |io|
            response.read_body { |chunk| io.write(chunk) }
          end
        else
          exit_with_error("Unable to download #{name}")
        end
      end
    end
  end

  def clean_downloads
    logger.debug('Removing any old versions of OTP or Elixir')
    Dir[File.join(@download_dir, '*')].
      reject { |file| [@otp_file, @elixir_file].include?(file) }.
      each { |file| File.delete(file) }
  end
end
