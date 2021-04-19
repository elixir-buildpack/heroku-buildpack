require_relative '../helper'
require_relative '../utils'
require 'fileutils'

class ElixirBuildpack::Compile
  include ElixirBuildpack::Utils
  include ElixirBuildpack::Helper

  def self.run
    new.run
  end

  def run
    logger.info('Compiling the application')

    get_deps
    compile
    clean_deps
  end

  private

  def get_deps
    logger.debug('Getting application dependencies')
    command_in_build('mix deps.get --only $MIX_ENV')
  end

  def compile
    logger.debug('Compiling application')
    unless config.pre_compile_command.empty?
      logger.debug('Running pre-compile command')
      command_in_build(config.pre_compile_command)
    end

    if config.compile_command.empty?
      command_in_build('mix compile --force')
    else
      logger.debug('Running custom compile command')
      command_in_build(config.compile_command)
    end

    unless config.post_compile_command.empty?
      logger.debug('Running post-compile command')
      command_in_build(config.post_compile_command)
    end
  end

  def clean_deps
    logger.debug('Removing unused application dependencies')
    command_in_build('mix deps.clean --unused')
  end
end
