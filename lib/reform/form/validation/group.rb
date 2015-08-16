module Reform::Form::Validation
  # DSL object wrapping the ValidationSet.
  # Translates the "Reform" DSL to the target validator gem's language.
  class Group
    def initialize
      @validations = Lotus::Validations::ValidationSet.new
    end

    def validates(*args)
      @validations.add(*args)
    end


    def call(fields, errors)
      validator = Lotus::Validations::Validator.new(@validations, fields, errors)
      validator.validate
    end
  end

  # Set of Validation::Group objects.
  # This implements adding, iterating, and finding groups, including "inheritance" and insertions.
  class Groups < Array
    def add(name, options)
      if options[:inherit]
        return self[name] if self[name]
      end

      i = index_for(options)

      self.insert(i, [name, group = Group.new, options])
      group
    end

    def index_for(options)
      return find_index { |el| el.first == options[:after] } + 1 if options[:after]
      size # default index: append.
    end

    def [](name)
      cfg = find { |cfg| cfg.first == name }
      return unless cfg
      cfg[1]
    end
  end

  module ClassMethods
    def validation(name, options={}, &block)
      group = validation_groups.add(name, options)

      group.instance_exec(&block)
    end

    def validation_groups
      @groups ||= Groups.new # TODO: inheritable_attr with Inheritable::Hash
    end


    def validates(name, options)
      validation(:default, inherit: true) { validates name, options }
    end

    def validate(name, *)
      # DISCUSS: lotus does not support that?
      # validations.add(name, options)
    end
  end

  def self.included(includer)
    includer.extend(ClassMethods)
  end

  def valid?
    result = true
    results = {}

    self.class.validation_groups.each do |cfg|
      name, group, options = cfg

      # validator = validator_for(group.validations)

      # puts "@@@@@ #{name.inspect}, #{_errors.inspect}"

      depends_on = options[:if]
      if depends_on.nil? or results[depends_on].empty?
        results[name] = group.(@fields, errors)
      end

      result &= errors.empty?
    end

    result
  end
end