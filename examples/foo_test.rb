require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

class FooTest < ActiveSupport::TestCase
  context "Blueprint" do 
    setup do
      @foo = ClayBlueprint::Clay(:foo)
    end
    should "have proper values" do
      assert_equal "foo", @foo.name
    end
  end
end
