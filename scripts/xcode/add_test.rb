require 'xcodeproj'
require 'pathname'

root = Pathname.new(__dir__).join('../..').expand_path
project_path = root.join('FloppyDuck.xcodeproj').to_s
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'FloppyDuckTests' }
group = project.main_group.find_subpath('FloppyDuckTests', true)

# check if it already exists
if !group.files.find { |f| f.path == 'GameSceneTests.swift' }
  file_ref = group.new_reference('GameSceneTests.swift')
  target.add_file_references([file_ref])
  project.save
  puts "Added test file to FloppyDuckTests target."
else
  puts "Test file already in project."
end
