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



