require 'test_helper'

class ClayBlueprintTest < ActiveSupport::TestCase
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
