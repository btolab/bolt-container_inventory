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
  attr_reader :options

  def task(opts)
    opts[:format] ||= 'groups'
    opts[:use_hostname] = true if opts[:use_hostname].nil?
    opts[:group_name_prefix] ||= ''
    opts[:ungrouped_name] || 'ungrouped_containers'
    data = resolve_reference(opts)
    return { value: data }
  rescue TaskHelper::Error => e
    puts opts.inspect
    # ruby_task_helper doesn't print errors under the _error key, so we have to
    # handle that ourselves
    return { _error: e.to_h }
  end

  # @return [Hash]
  def resolve_reference(opts)
    @options = opts
    format = opts[:format]
    group_name_prefix = opts[:group_name_prefix]
    parse_data(containers, format, group_name_prefix)
  end

  private

  # @return [Array] A array of container data
  def container_data(id)
    data = `docker inspect #{id}`
    JSON.parse(data).first
  end

  # @return [String] - the directory of the compose project
  def compose_dir(data)
    data['Config']['Labels'].fetch('com.docker.compose.project.working_dir', nil)
  end

  # @return [String] - the hostname of the container
  def container_hostname(data)
    data['Config']['Hostname']
  end

  # @return [String] - the name of the compose project or nil
  def compose_project(data)
    data['Config']['Labels'].fetch('com.docker.compose.project', nil)
  end

  # @return [Array] - array of container ids
  def containers
    out = `docker ps -q --filter status=running 2>&1`
    $CHILD_STATUS.success? ? out.split("\n") : []
  end

  def parse_data(dataset, format, _group_name_prefix)
    if format == 'groups'
      bolt_groups = dataset.each_with_object({}) do |container_id, groups|
        cdata = container_data(container_id)
        group_name = compose_project(cdata) || options[:ungrouped_name]
        unless groups.key?(group_name)
          groups[group_name] = {
            name: group_name,
            targets: [],
          }
        end
        name = options[:use_hostname] ? container_hostname(container_data(container_id)) : container_id
        groups[group_name][:targets] << { uri: name.to_s }
      end
      bolt_groups.values
    elsif format == 'targets'
      dataset.map do |container_id|
        name = options[:use_hostname] ? container_hostname(container_data(container_id)) : container_id
        { uri: name.to_s }
      end
    else
      raise TaskHelper::Error.new("Unknown format: #{format}", 'bad/data')
    end
  end
end

if $PROGRAM_NAME == __FILE__
  DockerInventory.run
end
