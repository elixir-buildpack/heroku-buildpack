require 'forwardable'

module ElixirBuildpack
  extend SingleForwardable

  def_delegators 'ElixirBuildpack::Main', :build_dir=, :build_dir
  def_delegators 'ElixirBuildpack::Main', :cache_dir=, :cache_dir
  def_delegators 'ElixirBuildpack::Main', :env_dir=, :env_dir

  def_delegators 'ElixirBuildpack::Main', :detect, :compile, :release

  def self.initialize
    require_relative 'elixir_buildpack/main'
  end
end
