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
    
    attr_accessor :states, :roles, :admin_roles, :staging_roles, :events, :initial_state, :default_role, :staging_state, :config
    attr_reader :name
    
    def initialize(name)
      @name   = name
      @initial_state = nil
      @default_role = nil
      @states = []
      @roles = []
      @admin_roles = []
      @staging_roles = []
      @staging_state = []
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
