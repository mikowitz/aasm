require 'ostruct'

module AASM
  class StateMachine
    def self.[](*args)
      (@machines ||= {})[args]
    end

    def self.[]=(*args)
      val = args.pop
      (@machines ||= {})[args] = val
    end
    
    attr_accessor :states, :roles, :events, :initial_state, :default_role, :config
    attr_reader :name
    
    def initialize(name)
      @name   = name
      @initial_state = nil
      @default_role = nil
      @states = []
      @roles = []
      @events = {}
      @config = OpenStruct.new
    end

    def clone
      klone = super
      klone.states = states.clone
      klone
    end

    def create_state(name, options)
      @states << AASM::SupportingClasses::State.new(name, options) unless @states.include?(name)
    end
    
    def create_role(name)
      @roles << name
    end
  end
end
