require 'open3'
require 'fileutils'
require 'pathname'

module ElixirBuildpack::Utils
  def rmdir(dir)
    return unless Dir.exist?(dir)

    command("rm -r #{dir}")
  end

  def mkdir(dir, delete_existing = false, depth = 10)
    rmdir(dir) if Dir.exist?(dir) && delete_existing
    return if Dir.exist?(dir)

    path = Pathname.new(dir)
    all_paths = [dir]
    depth.times { all_paths.prepend(path.parent) }
    all_paths.
      map(&:to_s).
      uniq.
      reject { |seg| Dir.exist?(seg) }.
      each { |seg| Dir.mkdir(seg) }
  end

  def cpdir(src, dest)
    FileUtils.copy_entry(src, dest, false, false, true)
  end

  def unzip(file, dest)
    command("unzip -q #{file} -d #{dest}")
  end

  def untar(file, dest)
    command("tar zxf #{file} -C #{dest} --strip-components=1")
  end

  def exit_with_error(error)
    ElixirBuildpack::Main.logger.fatal(error)
    Kernel.exit(1)
  end

  def print(msg)
    STDOUT.print(msg)
  end

  def prepend_path(path)
    ElixirBuildpack::Main.config.env['PATH'] =
      ElixirBuildpack::Main.config.env['PATH'].to_s.split(':').prepend(path).join(':')
  end

  def command(command)
    stdout_and_stderr, status = Open3.capture2e(ElixirBuildpack::Main.config.env, command)
    if status.exitstatus != 0
      ElixirBuildpack::Main.logger.fatal("failed to run command: #{command.inspect}")
      STDOUT.print(stdout_and_stderr)
      Kernel.exit(1)
    end
  end

  def command_in_build(command)
    env = ElixirBuildpack::Main.config.env.merge('HOME' => ElixirBuildpack::Main.build_dir)
    stdout_and_stderr, status = Open3.capture2e(env, command, chdir: ElixirBuildpack::Main.build_dir)
    if status.exitstatus != 0
      ElixirBuildpack::Main.logger.fatal("failed to run command: #{command.inspect}")
      STDOUT.print(stdout_and_stderr)
      Kernel.exit(1)
    end
  end
end
