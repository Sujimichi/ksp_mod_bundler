#!/usr/bin/env ruby

class ModBundler
  KSP_ROOT = "./KSPv0.17"

  def initialize args = []
    craft_file = args[0]
    craft_name = craft_file.split("/").last.sub(".craft","")
    @working_dir = Dir.getwd
    raise "You must specify a craft file" if craft_file.nil? || craft_file.empty? || !craft_file.match(/.craft$/)
    
    craft = Craft.new craft_file #read craft file and determine its parts
    current_parts = PartFinder.new "#{KSP_ROOT}/Parts" #read parts dir and index parts    
    required_parts = current_parts.select_for craft #determine which indexed parts are in craft

    build_bundle :with => required_parts, :for => craft_name
    

    #TODO
    #read mod zips and index parts
    #determine which indexed parts are in craft
    #show the mods that contain the parts
  
    #mod_reader = ModZipReader.new "./mod_repo"


  end

  def build_bundle args = {}
    required_parts = args[:with]
    craft_name = args[:for]

    puts "\nBuilding Mod Bundle for #{craft_name}"

    Dir.chdir(@working_dir)
    File.delete "#{craft_name}_mod_bundle.zip" if File.exists?("#{craft_name}_mod_bundle.zip")
    Zip::ZipFile.open("#{craft_name}_mod_bundle.zip", Zip::ZipFile::CREATE){ |zipfile|      
      zipfile.mkdir("Parts")
      zipfile.mkdir("Plugins")

      print "Carefully hand picking parts"
      required_parts.each do |part_folder|
        path = "#{KSP_ROOT}/Parts/#{part_folder}/**/**"
        Dir[path].each do |file|
          zip_path = file.sub("#{KSP_ROOT}/Parts/","")
          zipfile.add("Parts/#{zip_path}",file)  
          print "."
        end
      end

      #add all the Plugins from the KSP plugins folder
      print "\nadding ALL plugins, whateva!"
      Dir["#{KSP_ROOT}/Plugins/**/*.dll"].each do |file|
        zip_path = file.split("/").last
        zipfile.add("Plugins/#{zip_path}",file)  
        print "."
      end
    }

    bundle_size = (File.size?("#{craft_name}_mod_bundle.zip").to_f/2**20).round(2)

    puts "\n\nBundle Built - #{bundle_size}MB"

  end




end


class Craft
  attr_accessor :part_names

  def initialize file_path
    craft_data = File.open(file_path, "r"){|f| f.readlines}
    read_part_names_from craft_data
  end

  def read_part_names_from craft_data
    print "\nReading craft data (#{craft_data.size} lines)..."
    #select the lines which start \tpart = 
    parts = craft_data.select{ |line| line.match(/^\tpart =/) }
    print "Found #{parts.size} parts"

    #remove preceding and trailing text
    @part_names = parts.map{|part| 
      p = part.sub("\tpart = ","").split("_") #remove preceding text and split on '_'
      p[0..(p.size-2)].join.chomp #remove the trailing index number and \n\r chars
    }.uniq #remove duplicate part names
    puts ", #{@part_names.size} unique parts"
  end

  alias parts part_names

end

class PartFinder

  def initialize part_dir_path

    #cfg_files= Dir['**/*.cfg']
    print "Reading Parts folder..."
    Dir.chdir(part_dir_path)
    part_names = Dir.entries(Dir.pwd).map do |dir|
      next if [".",".."].include?(dir)
      cfg = File.open("#{dir}/part.cfg","r"){|f| f.readlines}
      
      part_name = cfg.select{|line| line.include?("name =")}.first.sub("name = ","").chomp
      raise "part name not found" if part_name.nil? || part_name.empty?
      {:name => part_name, :dir => dir }
      
    end.compact #call compact on array returned from do..end block
    puts "Found #{part_names.size} parts"

    dups = part_names.select{|n|
      t = n[:name]
      part_names.select{|i| i[:name] == t}.size != 1
    }
    puts "\nThese parts have the same part name in cfg but occur in different folders"
    puts dups.group_by{|g| g[:name]}.map{|k,v| {k => v.map{|d| d[:dir]}}}

    #convert array of hashes into a hash indexed by part name.  {:part_name => {:dir => String}}
    #dup parts lost at this stage.  Might change that if it proves to be a problem.
    #I'm working on the assumption that the name in the part.cfg should be a unique name, but thats just a guess.
    @index = part_names.map{|n| {n[:name] => {:dir => n[:dir]}}}.inject{|i,j| i.merge(j)}
  end

  def locate part
    @index[part]
  end

  def select_for craft
    print "\n\nLocating craft parts"
    not_found = []
    required_part_paths = craft.parts.map do |part|
      dir = locate(part)
      dir = locate(part.gsub(".","_")) if dir.nil? #some need '.' replacing with '_'

      r = (dir.nil? || dir.empty?) ? nil : dir[:dir] #return the dir, or nil if nothing was found
      not_found << part if r.nil? #track not found parts
      print "."
      r
    end.compact

    puts "Found #{required_part_paths.size}"
    puts "Unable to locate #{not_found.size} parts:\n#{not_found}" unless not_found.empty?
    required_part_paths
  end

end

class ModZipReader
  require 'zip/zip'

  def initialize mod_dir

    Dir.chdir(mod_dir)    
    zips = Dir['*.zip'] #can only handle zips currently
    puts "Found #{zips.size} zips"
    read_and_index zips
   

  end

  def read_and_index zips
    zips.each do |zip|
      Zip::ZipFile.open(zip){|zipfile|

        cfgs = zipfile.select do |file|
          file.name.match(/.cfg$/)
        end
        puts cfgs

      }
    
    end

  end


end


ModBundler.new ARGV

