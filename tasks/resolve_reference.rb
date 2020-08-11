
#!/usr/bin/env ruby

task_helper = [
  # During a real bolt call, ruby_task_helper modules is installed in same directory as this module
  File.join(__dir__, '..', '..', 'ruby_task_helper', 'files', 'task_helper.rb'),
  # During development the ruby_task_helper module will be in the test module fixtures
  File.join(__dir__, '..', 'spec', 'fixtures', 'modules', 'ruby_task_helper', 'files', 'task_helper.rb'),
].find { |helper_path| File.exist?(helper_path) }
raise 'Could not find the Bolt ruby_task_helper' if task_helper.nil?
require_relative task_helper


# Retrieves hosts from the docker host
class DockerInventory < TaskHelper
  TRANSPORT = 'docker://'

  def resolve_reference(opts)
    format = opts[:format] || 'targets'
    group_name_prefix = opts[:group_name_prefix] || ''
    parse_data(containers, format, group_name_prefix)
  end

  def containers
    `docker ps -q --filter status=running`.split("\n")
  end

  def parse_data(dataset, format, group_name_prefix)
    # if format == 'groups'
    #   dataset.each_with_object({}) do |container_id, groups|
    #     unless groups.key?(group_name)
    #       groups[group_name] = {
    #         name: group_name,
    #         targets: [],
    #       }
    #     end
    #     groups[group_name][:targets] << { uri: container_id }
    #   end
    #   groups.values
    if format == 'targets'
      dataset.map { |container_id| {uri: "#{TRANSPORT}#{container_id}" } }
    else
      raise TaskHelper::Error.new("Unknown format: #{format}", 'bad/data')
    end
  end

  def task(opts)
    data = resolve_reference(opts)
    return { value: data }
  rescue TaskHelper::Error => e
    # ruby_task_helper doesn't print errors under the _error key, so we have to
    # handle that ourselves
    return { _error: e.to_h }
  end
end

if $PROGRAM_NAME == __FILE__
  DockerInventory.run
end