module ElixirBuildpack::Helper
  def logger
    ElixirBuildpack::Main.logger
  end

  def config
    ElixirBuildpack::Main.config
  end
end
