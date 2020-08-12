
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
  attr_reader :options

  def resolve_reference(opts)
    @options = opts
    format = opts[:format] || 'groups'
    group_name_prefix = opts[:group_name_prefix] || ''
    parse_data(containers, format, group_name_prefix)
  end

  def container_data(id)
    data = `docker inspect #{id}`
    JSON.parse(data).first
  end

  def compose_dir(data)
    data['Config']['Labels']["com.docker.compose.project.working_dir"]
  end

  def container_hostname(data)
    data['Config']['Hostname']
  end

  def compose_project(data)
    data['Config']['Labels']["com.docker.compose.project"]
  end

  def containers
    `docker ps -q --filter status=running`.split("\n")
  end

  def parse_data(dataset, format, group_name_prefix)
    if format == 'groups'
      groups = dataset.each_with_object({}) do |container_id, groups|
        cdata = container_data(container_id)
        group_name = compose_project(cdata) || 'ungrouped_containers'
        unless groups.key?(group_name)
          groups[group_name] = {
            name: group_name,
            targets: [],
          }
        end
        name = options[:use_hostname] ? container_hostname(container_data(container_id)) : container_id
        groups[group_name][:targets] << {uri: "#{TRANSPORT}#{name}" } 
      end
      groups.values
    elsif format == 'targets'
      dataset.map do |container_id| 
        name = options[:use_hostname] ? container_hostname(container_data(container_id)) : container_id
        {uri: "#{TRANSPORT}#{name}" } 
      end
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