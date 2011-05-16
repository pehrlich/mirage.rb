#!/usr/bin/ruby
p "Miraging Directory Structure"

require "fileutils"
#require 'directory_watcher'
require "rubygems"
require "rails"

class Pdir < Dir
  def self.foreach(dirname)
    if File.exists?(dirname)
      super
    end
  end
end

class Object
  alias_method :try, :__send__
end

class NilClass
  def try(*args)
    nil
  end
end

class Array
  def ===(val)
    self.include? val
  end
end


def ensure_mirage_link(from, to)
  # todo: use fileutils for ln_s
  to = Pathname.new(File.join('mirage', to))
  from = Pathname.new(from)

  FileUtils.mkpath to.dirname

  unless to.exist?
    p "#{to}"
    FileUtils.ln_s(from.relative_path_from(to.dirname), to)
  end
end

def link_structure
  {
      'app/controllers' => proc { |fn| (fn.match /(.*)_controller.rb/i).try(:'[]', 1) },
      'app/helpers' => proc { |fn| (fn.match /(.*)_helper.rb/i).try(:'[]', 1) },
      'app/models' => proc { |fn| (fn.match /(.*).rb/i).try(:'[]', 1).try(:pluralize) },
  }.each do |path, resourceNameFinder|
    Pdir.foreach(path) do |filename|
      filepath = File.join(path, filename)
      if File.directory?(filepath) && filename.index('.').nil?
        ensure_mirage_link(# controllers/admin => admin/controllers
        File.join(filepath),
        File.join(filename, path.split('/').last)
        )
      else # controllers/application_controller.rb => application/application_controller.rb
        if resource_name = resourceNameFinder.call(filename)
          ensure_mirage_link(
              filepath,
              File.join(resource_name, filename)
          )
        end
      end
    end
  end

#  each_file 'app/viewds' do |folder|
  Pdir.foreach('app/views') do |folder|
    case folder
      when ['.', '..']
      when 'layouts' # views/layouts => application/layouts
        ensure_mirage_link(
            File.join('app/views', folder),
            File.join('application', folder)
        )
      else # views/comments => comments/views
        ensure_mirage_link(
            File.join('app/views', folder),
            File.join(folder, 'views')
        )
    end
  end

  {
      'app/assets/javascripts' => /(.*)\.js(\.coffee)?/i,
      'app/assets/stylesheets' => /(.*)\.css(\.scss)?/i
  }.each do |basepath, regexp|
    Pdir.foreach(basepath) do |file|
      case file
        when ['.', '..']
        when regexp # assets/javascripts/comment.js.coffee => comments/comment.js.coffee
          ensure_mirage_link(
              File.join(basepath, file),
              File.join($1, file)
          )
        else # assets/javascripts/whatever => application/whatever
          ensure_mirage_link(
              File.join(basepath, file),
              File.join('application', file)
          )
      end
      # an interesting use for this method might be to check and only move scripts to already existing resource
      # specific folders, so that jquery.js goes to application/jquery.js rather than jquery/jquery.js
    end
  end

end

#
#def watch # currently pseudocode
#  # http://codeforpeople.rubyforge.org/directory_watcher/classes/DirectoryWatcher.html
#  dw = DirectoryWatcher.new 'app/**/*'# , :scanner => :rev
#  dw.add_observer {|*args| args.each {|event| puts event}}
#  dw.start
#  gets      # when the user hits "enter" the script will terminate
#  dw.stop
#end


def watch_sass
  sass_pids = []
  Pdir.foreach('app/assets/stylesheets') do |file|
    if file.match /(.*)(\.scss)/i
      p "watching #{file}"
      sass_pids << spawn("sass --watch app/assets/stylesheets/#{file}:app/assets/stylesheets/#{$1}")
    end
  end
  sass_pids
end

def kill_proccesses(ids)
  ids.each { |id| `kill #{id}` }
end

link_structure
#sass_pids = watch_sass
#kill_proccesses ids
#p "releaved - #{sass_pids.inspect}"