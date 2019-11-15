class Exec
  def self.call(cmd)
    `#{cmd}`.tap do
      if (status = $?.exitstatus) != 0
        raise "#{cmd} exited with status #{status}"
      end
    end
  end
end
