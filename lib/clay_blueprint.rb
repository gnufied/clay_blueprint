# ClayBlueprint
require "rubygems"
gem "activesupport", "2.3.8"
require "active_support"

# TODO
# 1. Make sure that blueprints should be reusable
# 2. Should be able to return hashed value if needed
# 3. Specify a way to make association
# 4. Should be automatically loaded from particular rails project directory

module ClayBlueprint
  class InvalidClay < StandardError; end
  class InvalidClayCreationBlock < StandardError; end
  class DuplicateClayDefinition < StandardError; end

  def self.Clay(name,options = {})
    klass_name = (options[:class] || name).to_s.classify
    options.delete(:class)
    object = Clay.defined_clays[name]
    raise InvalidClay.new("Invalid clay #{name}") unless object
    klass = object.class
    new_object = klass.allocate()
    new_object.extend(ExtendClayClass)
    new_object.copy_clay_attributes(object)
    new_object.override_clay_attribute(options)
    new_object
  end

  def self.find_clay_blueprints(project_root)
    Dir["#{project_root}/test/blueprints/*.rb"].each do |blueprint_file|
      load blueprint_file
    end
  end
  
  class Clay
    @@defined_clays = {}
    cattr_accessor :defined_clays
    class << self
      def define(name,options = {},&block)
        klass_name = (options[:class] || name).to_s.classify
        check_duplicate_definition(name,options)
        const_name = Object.const_defined?(klass_name) && Object.const_get(klass_name)
        object = nil
        if const_name
          object = const_name.allocate()
          object.extend(ExtendClayClass)
        else
          klass = Object.const_set(klass_name,Class.new())
          object = klass.allocate()
          object.extend(ExtendClayClass)
        end
        object.clay_creation_block(&block)
        @@defined_clays[name] = object
        object
      end

      def check_duplicate_definition(name,options)
        old_object = @@defined_clays[name]
        if (old_object && !options[:force])
          raise DuplicateClayDefinition.new("Clay #{name} has been already defined") 
        end
      end
    end
  end

  module ExtendClayClass

    def clay_creation_block(&block)
      if block_given?
        @clay_creation_block = block
      elsif @clay_creation_block
        @clay_creation_block
      else
        raise InvalidClayCreationBlock.new("Invalid clay creation block")
      end
    end

    def override_clay_attribute(attributes)
      attributes.each do |key,value|
        set_clay_attribute(key,value)
      end
    end

    def copy_clay_attributes(object)
      object.clay_creation_block.call(self)
    end

    def clay_attributes(name = nil,value = nil)
      if(!name && !value)
        @clay_attributes
      else
        @clay_attributes ||= {}
        @clay_attributes[name] = value
      end
    end

    def set_clay_attribute(name,value)
      if self.respond_to?("#{name}=")
        self.send("#{name}=",value)
      else
        self.instance_variable_set("@#{name}",value)
        self.instance_eval("def #{name}; @#{name}; end", __FILE__, __LINE__) if !self.respond_to?(name)
      end
      clay_attributes(name,value)
    end

    def method_missing(name,*args,&block)
      if !name.blank? && !args.blank? && self.respond_to?("#{name}=")
        set_clay_attribute(name,args.first)
      elsif !name.blank? && !args.blank?
        set_clay_attribute(name,args.first)
      end
    end
  end
end



if __FILE__ == $0
  require "test/unit"
  require "shoulda"
  
  class TestClay < Test::Unit::TestCase
    context "For Clays" do
      setup do
        ClayBlueprint::Clay.define(:foo, :force => true) do |f|
          f.name "Hemant Kumar"
          f.age 10
        end
      end

      should "create objects from blueprint" do
        @clay = ClayBlueprint::Clay(:foo)
        assert_equal "Hemant Kumar", @clay.name
        assert_equal 10, @clay.age
        assert_equal({ :age => 10, :name => "Hemant Kumar"}, @clay.clay_attributes)
      end

      should "each object created from blueprint should be different" do
        @clay1 = ClayBlueprint::Clay(:foo)
        @clay2 = ClayBlueprint::Clay(:foo)
        assert (@clay1.object_id != @clay2.object_id)
      end
    end

    context "For clay association" do
      setup do
        ClayBlueprint::Clay.define(:x) do |x|
          x.name "x"
          x.age 20
        end

        ClayBlueprint::Clay.define(:y) do |y|
          y.sex 'm'
          y.profile ClayBlueprint::Clay(:x)
        end
      end

      should "setup association" do
        y = ClayBlueprint::Clay(:y)
        assert_equal 'm', y.sex
        assert_equal 'x', y.profile.name
        assert_equal 20, y.profile.age
      end
    end

    context "Clay attributes can be overriden" do
      setup do
        ClayBlueprint::Clay.define(:bar) do |b|
          b.name "Bar"
          b.age 12
        end
      end

      should "be able to override values" do
        b = ClayBlueprint::Clay(:bar, :name => "Hemant")
        assert_equal "Hemant", b.name
        assert_equal 12, b.age
      end
    end

    context "If same clay is defined twice" do
      should "detect any conflict and raise exception" do
        ClayBlueprint::Clay.define(:conflict) do |c|
          c.message "Hello"
          c.status 10
        end
        assert_raise(ClayBlueprint::DuplicateClayDefinition) do
          ClayBlueprint::Clay.define(:conflict) do |c|
            c.content "Foo"
            c.title "conflict"
          end
        end
      end
    end

    context "Blueprint clays for existing classes" do
      setup do
        class Emacs
          attr_accessor :name
        end
        ClayBlueprint::Clay.define(:emacs) do |e|
          e.name "Editor"
        end
      end
      should "work as usual" do
        emacs = ClayBlueprint::Clay(:emacs)
        assert_equal "Editor", emacs.name
      end
    end

    context "Same class but with different name" do
      setup do
        ClayBlueprint::Clay.define(:lesson, :class => "Lesson") do |l|
          l.name "foo"
          l.content "bar"
          l.size 10
        end

        ClayBlueprint::Clay.define(:lesson_without_content,:class => "Lesson") do |l|
          l.name "lesson1"
          l.size 20
        end
      end

      should "work without creating conflicts" do
        a = ClayBlueprint::Clay(:lesson)
        assert_equal 'foo', a.name
        assert_equal 'bar', a.content
        assert_equal 10, a.size

        b = ClayBlueprint::Clay(:lesson_without_content)
        assert_equal 'lesson1', b.name
        assert_nil b.content
        assert_equal 20, b.size
      end
    end
  end
end
