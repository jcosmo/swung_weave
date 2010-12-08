VERSION_NUMBER = "1.0.14"
GROUP = "org.realityforge.swung-weave"

require 'buildr_bnd'
require 'buildr_iidea'

OPENAPI = group('openapi', 'idea', 'idea_rt', 'util', 'extensions', 'annotations', :under => 'com.intellij', :version => '9.0.3')

class CentralLayout < Layout::Default
  def initialize(key, top_level, use_subdir)
    super()
    prefix = top_level ? '' : '../'
    subdir = use_subdir ? "/#{key}" : ''
    self[:target] = "#{prefix}target#{subdir}"
    self[:target, :main] = "#{prefix}target#{subdir}"
    self[:reports] = "#{prefix}reports#{subdir}"
  end
end

def define_with_central_layout(name, top_level = false, use_subdir = true, options = {}, & block)
  define(name, {:layout => CentralLayout.new(name, top_level, use_subdir)}.update(options), & block)
end

desc 'SwungWeave: Bytecode weaver to simplify Swing UI code'
define_with_central_layout("swung-weave", true, false) do
  project.version = VERSION_NUMBER
  project.group = GROUP

  ipr.extra_modules << 'idea/idea.iml'

  desc "SwungWeave: API and Annotations"
  define_with_central_layout "api" do
    test.using :testng
    package(:bundle).tap do |bnd|
      bnd['Export-Package'] = "org.realityforge.swung_weave.*;version=#{version}"
    end
    package(:sources)
  end

  desc "SwungWeave: Bytecode weaver tool"
  define_with_central_layout "tool" do
    compile.with :asm, projects('api')
    test.using :testng
    package(:bundle).tap do |bnd|
      bnd['Export-Package'] = "org.realityforge.swung_weave.tool.*;version=#{version}"
      bnd['Private-Package'] = "org.objectweb.asm.*"
    end
  end

  desc "SwungWeave: IntelliJ IDEA plugin"
  define "idea-plugin", :base_dir => 'idea', :layout => CentralLayout.new('idea-plugin', false, true) do
    compile.with OPENAPI, :jdom, projects('tool')
    project.no_iml
    project.resources.filter.using :"version" => project.version 
    test.using :testng
    package(:jar)
  end

  desc "SwungWeave: Buildr extension"
  define_with_central_layout "buildr" do

    generated_file = _(:target, :generated, "version.rb")
    file(generated_file => Buildr.application.buildfile) do
      mkdir_p File.dirname(generated_file)
      File.open(generated_file, "wb") do |f|
        f.write <<TEXT
module Buildr
  module SwungWeave
    private
      VERSION="#{VERSION_NUMBER}"
      ASM_ARTIFACT="#{artifact(:asm).to_spec}"
      GROUP="#{GROUP}"
  end
end
TEXT
      end
    end
    package(:gem).tap do |gem|
      gem.spec do |spec|
        spec.authors        = ['Peter Donald']
        spec.email          = ["peter@realityforge.org"]

        spec.homepage       = "http://github.com/realityforge/swung_weave"
        spec.summary        = "Buildr extension to run the swung_weave tool"
        spec.description    = <<-TEXT
Buildr extension to process bytecode using swung-weaver. Swung weaver is
bytecode weaving of annotated UI classes to ensure all UI updates occur
in the Event Dispatch Thread
TEXT
        spec.require_paths  = ['lib']
        spec.has_rdoc         = false
      end
      gem.include :from => _("lib"), :path => "lib"
      gem.include ['LICENSE', 'README.rdoc', 'NOTICE']
      gem.include generated_file, :as => "lib/buildr/swung_weave/version.rb"
      gem.prerequisites << generated_file
    end
  end
end

namespace :deploy do
  desc "Tag release with current version"
  task :tag do
    system("git tag -a #{VERSION_NUMBER} -m 'Released #{VERSION_NUMBER}'")
    puts "Tagged locally.  `git push --tags` if you're sure."
  end
end
