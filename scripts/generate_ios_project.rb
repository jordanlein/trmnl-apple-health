#!/usr/bin/env ruby

require "pathname"
require "xcodeproj"

repo_root = Pathname.new(__dir__).parent
project_root = repo_root.join("ios", "TRMNLHealthSync")
source_root = project_root.join("TRMNLHealthSync")
project_path = project_root.join("TRMNLHealthSync.xcodeproj")

FileUtils.rm_rf(project_path) if project_path.exist?

project = Xcodeproj::Project.new(project_path.to_s)
target = project.new_target(:application, "TRMNLHealthSync", :ios, "17.0")
project.root_object.attributes["LastUpgradeCheck"] = "1650"

source_group = project.main_group.find_subpath("TRMNLHealthSync", true)

Dir[source_root.join("**", "*")].sort.each do |path|
  next if File.directory?(path)

  relative_path = Pathname(path).relative_path_from(project_root).to_s
  reference = source_group.new_file(relative_path)

  case File.extname(path)
  when ".swift"
    target.add_file_references([reference])
  when ".entitlements"
    # Referenced from build settings only.
  end
end

frameworks_group = project.frameworks_group
%w[
  HealthKit.framework
  Security.framework
].each do |framework_name|
  reference = frameworks_group.new_file("System/Library/Frameworks/#{framework_name}")
  target.frameworks_build_phase.add_file_reference(reference)
end

project.build_configurations.each do |config|
  config.build_settings["CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER"] = "YES"
  config.build_settings["SWIFT_VERSION"] = "5.0"
end

target.build_configurations.each do |config|
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = ""
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = "TRMNLHealthSync/TRMNLHealthSync.entitlements"
  config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
  config.build_settings["CURRENT_PROJECT_VERSION"] = "1"
  config.build_settings["DEVELOPMENT_TEAM"] = ""
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "YES"
  config.build_settings["INFOPLIST_KEY_CFBundleDisplayName"] = "TRMNL Health Sync"
  config.build_settings["INFOPLIST_KEY_NSHealthShareUsageDescription"] = "TRMNL Health Sync reads your Apple Health data to mirror your daily activity on TRMNL and Home Assistant."
  config.build_settings["INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents"] = "YES"
  config.build_settings["INFOPLIST_KEY_UILaunchScreen_Generation"] = "YES"
  config.build_settings["INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone"] = [
    "UIInterfaceOrientationPortrait",
  ]
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
  config.build_settings["LD_RUNPATH_SEARCH_PATHS"] = [
    "$(inherited)",
    "@executable_path/Frameworks",
  ]
  config.build_settings["MARKETING_VERSION"] = "0.1.0"
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "io.github.jordanleinberger.trmnlhealthsync"
  config.build_settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
  config.build_settings["SUPPORTED_PLATFORMS"] = "iphoneos iphonesimulator"
  config.build_settings["SUPPORTS_MACCATALYST"] = "NO"
  config.build_settings["SWIFT_EMIT_LOC_STRINGS"] = "YES"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["TARGETED_DEVICE_FAMILY"] = "1"
end

project.save
puts "Generated #{project_path}"
