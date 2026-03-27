require 'xcodeproj'

project_path = '/Users/xanderevans/Documents/floppyduck/FloppyDuck.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target_name = 'FloppyDuck'
target = project.targets.find { |t| t.name == target_name }
if target.nil?
  puts "Target #{target_name} not found!"
  exit 1
end

# Get all files in the "Compile Sources" build phase
compile_sources_files = target.source_build_phase.files_references.map(&:real_path).map(&:to_s)

# Directories to check (relative to project root)
check_dirs = ['FloppyDuck']

# Extensions to check
extensions = ['.swift']

missing_files = []

check_dirs.each do |dir|
  full_dir_path = File.join('/Users/xanderevans/Documents/floppyduck', dir)
  Dir.glob(File.join(full_dir_path, '**', '*')).each do |file_path|
    next unless extensions.include?(File.extname(file_path))
    
    # Exclude files that are known to be in other targets or not in "Compile Sources"
    # (e.g., test files if they are in the same directory, though usually they're not)
    next if file_path.include?('Tests.swift') 
    
    unless compile_sources_files.include?(file_path)
      missing_files << file_path
    end
  end
end

if missing_files.empty?
  puts "✅ All Swift files are correctly included in the #{target_name} target."
  exit 0
else
  puts "❌ Found #{missing_files.size} Swift files NOT included in the #{target_name} target:"
  missing_files.each { |f| puts "   - #{f}" }
  puts "\nRun `ruby add_models.rb` (or a similar script) to fix this, or add them manually in Xcode."
  exit 1
end
