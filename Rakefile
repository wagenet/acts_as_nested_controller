# Inspired by the one from http://github.com/mislav/will_paginate

require 'rubygems'
begin
  require 'hanna/rdoctask'
rescue LoadError
  require 'rake'
  require 'rake/rdoctask'
end

task :default => :rdoc

desc 'Generate RDoc documentation for the acts_as_nested_controller plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_files.include('README.rdoc').
    include('lib/**/*.rb').
    exclude('lib/acts_as_nested_controller/*')
  
  rdoc.main = "README.rdoc" # page to start on
  rdoc.title = "acts_as_nested_controller documentation"
  
  rdoc.rdoc_dir = 'doc' # rdoc output folder
  rdoc.options << '--inline-source' << '--charset=UTF-8'
  rdoc.options << '--webcvs=http://github.com/rxcfc/acts_as_nested_controller/tree/master/'
end