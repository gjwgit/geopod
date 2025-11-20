#!/usr/bin/env ruby
#
# 20251118 jesscmoore Generate new macos flavor for automating
# a custom build configuration
# Refs:
# - https://savviness.dev/xcodeproj/
# - https://docs.flutter.dev/deployment/flavors-ios

require 'xcodeproj'

if ARGV.include?('-h') || ARGV.include?('--help') || ARGV.length != 1
  puts "Usage: ruby create_macos_flavor.rb [flavor]"
  puts ""
  puts "-h, --help: Show this help message."
  puts "flavor:     Where flavor is the name of the new flavor (Default: none)."
  exit
end

# Get scheme name from command line
flavor = ARGV[0]
debug_conf_name = "Debug-#{flavor}"
profile_conf_name = "Profile-#{flavor}"
release_conf_name = "Release-#{flavor}"
project_path = '../macos/Runner.xcodeproj'
shared_schemes_dir = File.join(project_path, 'xcshareddata', 'xcschemes')

scheme = Xcodeproj::XCScheme.new
project = Xcodeproj::Project.open(project_path)

def list_build_configs(project)
    project.build_configurations.each do |configuration|
        puts "  - #{configuration.name}"
    end
end

def list_schemes(shared_schemes_dir)
    if File.exist?(shared_schemes_dir)
        Dir.entries(shared_schemes_dir).each do |filename|
            if filename.end_with?('.xcscheme')
                puts "  - #{File.basename(filename, '.xcscheme')}"
            end
        end
    else
        puts "  No shared schemes found."
    end
end

# Generate new build configurations by duplicating existing build config
def copy_configuration(project, base_name, new_config_name, symbol_name)
    runner = project.native_targets[0]

    new_configuration = project.add_build_configuration(new_config_name, symbol_name)
    new_native_configuration = runner.add_build_configuration(new_config_name, symbol_name.to_s)

    source_configuration = runner.build_configurations.detect {|element| element.name.downcase == symbol_name.to_s}

    new_native_configuration.base_configuration_reference = source_configuration.base_configuration_reference

    project.build_configurations.each do |configuration|
        if configuration.name == base_name
            new_configuration.build_settings = configuration.build_settings
        end
    end

    runner.build_configurations.each do |configuration|
        if configuration.name == base_name
            new_native_configuration.build_settings = configuration.build_settings
        end
    end

    project.save()
end


# List build configurations
puts "Initial build configurations for project '#{project.path.basename}':"
list_build_configs(project)

# List schemes
puts "Initial shared schemes (flavors) for project '#{project.path.basename}':"
list_schemes(shared_schemes_dir)


# Create the build configurations
copy_configuration(project, 'Debug', debug_conf_name, :debug)
copy_configuration(project, 'Profile', profile_conf_name, :release)
copy_configuration(project, 'Release', release_conf_name, :release)

# Create new scheme
runner = project.native_targets[0]
scheme.add_build_target(runner)
scheme.launch_action.build_configuration=debug_conf_name
scheme.test_action.build_configuration=debug_conf_name
scheme.profile_action.build_configuration=profile_conf_name
scheme.analyze_action.build_configuration=debug_conf_name
scheme.archive_action.build_configuration=release_conf_name
scheme.save_as(project_path, flavor)

# list build configurations
puts ""
puts "Final build configurations for project '#{project.path.basename}':"
list_build_configs(project)

# list schemes
puts "Final schemes (flavors) for project '#{project.path.basename}':"
list_schemes(shared_schemes_dir)
