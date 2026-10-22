# frozen_string_literal: true

# Adds the iOS flavors Flutter's --flavor expects to ios/Runner.xcodeproj:
# a <Mode>-<flavor> build configuration in every configuration list and a
# shared scheme named after each flavor. Runs on macOS (Codemagic) before
# `flutter build ios --flavor <flavor>`, and on any machine with the xcodeproj
# gem. Idempotent: existing configurations are reused and the schemes are
# regenerated from Runner.xcscheme, which is never modified.
#
# Bundle IDs and display names are not set here; they live in
# ios/Flutter/Flavor-<flavor>.xcconfig.

require 'xcodeproj'

FLAVORS = %w[dev prod].freeze
MODES = %w[Debug Release Profile].freeze

ios_dir = File.expand_path('..', __dir__)
project_path = File.join(ios_dir, 'Runner.xcodeproj')
schemes_dir = File.join(project_path, 'xcshareddata', 'xcschemes')

project = Xcodeproj::Project.open(project_path)
flutter_group = project.main_group.groups.find { |group| group.display_name == 'Flutter' } ||
                abort('configure_flavors: no Flutter group in Runner.xcodeproj')
runner = project.native_targets.find { |target| target.name == 'Runner' } ||
         abort('configure_flavors: no Runner target')

def duplicate_configuration(list, source_name, name)
  existing = list[name]
  return existing if existing

  source = list[source_name] || abort("configure_flavors: no #{source_name} configuration")
  copy = list.project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  copy.name = name
  copy.build_settings = Marshal.load(Marshal.dump(source.build_settings))
  copy.base_configuration_reference = source.base_configuration_reference
  list.build_configurations << copy
  copy
end

def xcconfig_reference(group, name)
  path = "Flutter/#{name}.xcconfig"
  group.files.find { |file| file.path == path } || group.new_reference(path)
end

lists = [project.build_configuration_list] + project.targets.map(&:build_configuration_list)

FLAVORS.each do |flavor|
  MODES.each do |mode|
    name = "#{mode}-#{flavor}"
    unless File.exist?(File.join(ios_dir, 'Flutter', "#{name}.xcconfig"))
      abort("configure_flavors: missing ios/Flutter/#{name}.xcconfig")
    end
    lists.each { |list| duplicate_configuration(list, mode, name) }

    runner_configuration = runner.build_configuration_list[name]
    runner_configuration.base_configuration_reference = xcconfig_reference(flutter_group, name)
    # The flavor xcconfig supplies it; a target-level value would override it.
    runner_configuration.build_settings.delete('PRODUCT_BUNDLE_IDENTIFIER')
  end
end

project.save

template = File.read(File.join(schemes_dir, 'Runner.xcscheme'))
FLAVORS.each do |flavor|
  replaced = 0
  scheme = template.gsub(/buildConfiguration = "(Debug|Release|Profile)"/) do
    replaced += 1
    %(buildConfiguration = "#{Regexp.last_match(1)}-#{flavor}")
  end
  abort("configure_flavors: expected 5 scheme actions, found #{replaced}") unless replaced == 5
  File.write(File.join(schemes_dir, "#{flavor}.xcscheme"), scheme)
end

puts "configure_flavors: #{FLAVORS.join(', ')} x #{MODES.join(', ')} configured"
