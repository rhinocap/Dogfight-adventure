#!/usr/bin/env ruby
# Generates DogfightAdventures.xcodeproj from the Swift sources.
# Idempotent: regenerates the project from scratch each run.

require 'xcodeproj'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
PROJ = File.join(ROOT, 'DogfightAdventures.xcodeproj')

FileUtils.rm_rf(PROJ)
project = Xcodeproj::Project.new(PROJ)

target = project.new_target(:application, 'DogfightAdventures', :ios, '16.0')

# Source group + files.
group = project.main_group.new_group('Sources', 'DogfightAdventures/Sources')
Dir.glob(File.join(ROOT, 'DogfightAdventures/Sources/*.swift')).sort.each do |f|
  ref = group.new_reference(File.basename(f)) # group already carries the Sources path
  target.add_file_references([ref])
end

project.main_group.new_file('DogfightAdventures/Info.plist')

# App icon / asset catalog + baked Bay data resources.
res_group = project.main_group.new_group('Resources', 'DogfightAdventures/Resources')
target.add_resources([res_group.new_reference('Assets.xcassets')])
%w[bay_meta.json bay_heightmap.f32 bay_texture.jpg].each do |res|
  path = File.join(ROOT, 'DogfightAdventures/Resources', res)
  target.add_resources([res_group.new_reference(res)]) if File.exist?(path)
end

orientations = %w[UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight]

target.build_configurations.each do |config|
  s = config.build_settings
  s['SWIFT_VERSION'] = '5.0'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.cunliffe.dogfightadventures'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['INFOPLIST_FILE'] = 'DogfightAdventures/Info.plist'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
  s['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  s['ENABLE_PREVIEWS'] = 'NO'
  s['MARKETING_VERSION'] = '1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['DEVELOPMENT_TEAM'] = '8W34JFWLTB'
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
end

project.save

# Shared scheme so `xcodebuild -scheme` works headlessly.
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as(PROJ, 'DogfightAdventures', true)

puts "Wrote #{PROJ}"
puts "Sources: #{target.source_build_phase.files.count} files"
