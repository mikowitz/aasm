require File.join(File.dirname(__FILE__), 'event')
require File.join(File.dirname(__FILE__), 'staged_event')
require File.join(File.dirname(__FILE__), 'state')
require File.join(File.dirname(__FILE__), 'state_machine')
require File.join(File.dirname(__FILE__), 'persistence')

module AASM
  def self.Version
    '2.0.5'
  end

  class InvalidTransition < RuntimeError
  end

  class UndefinedState < RuntimeError
  end
  
  def self.included(base) #:nodoc:
    # TODO - need to ensure that a machine is being created because
    # AASM was either included or arrived at via inheritance.  It
    # cannot be both.
    base.extend AASM::ClassMethods
    AASM::Persistence.set_persistence(base)
    AASM::StateMachine[base] = AASM::StateMachine.new('')
  end

  module ClassMethods
    def inherited(klass)
      AASM::StateMachine[klass] = AASM::StateMachine[self].clone
      super
    end
    
    def aasm_initial_state(set_state=nil)
      if set_state
        AASM::StateMachine[self].initial_state = set_state
      else
        AASM::StateMachine[self].initial_state
      end
    end
    
    def aasm_initial_state=(state)
      AASM::StateMachine[self].initial_state = state
    end
    
    def aasm_state(name, options={})
      sm = AASM::StateMachine[self]
      sm.create_state(name, options)
      sm.initial_state = name unless sm.initial_state

      define_method("#{name.to_s}?") do
        aasm_current_state == name
      end
    end
    
    def aasm_default_role(set_role=nil)
      if set_role
        AASM::StateMachine[self].default_role = set_role
      else
        AASM::StateMachine[self].default_role
      end
    end

    def aasm_default_role=(role)
      AASM::StateMachine[self].default_role = role
    end

    def aasm_role(name)
      sm = AASM::StateMachine[self]
      sm.create_role(name)
      sm.default_role = name unless sm.default_role
    end

    def aasm_event(name, options = {}, &block)
      sm = AASM::StateMachine[self]
      
      unless sm.events.has_key?(name)
        sm.events[name] = AASM::SupportingClasses::Event.new(name, options, &block)
      end

      define_method("#{name.to_s}!") do |*args|
        aasm_fire_event(name, true, *args)
      end

      define_method("#{name.to_s}") do |*args|
        aasm_fire_event(name, false, *args)
      end
    end

    def aasm_states
      AASM::StateMachine[self].states
    end

    def aasm_roles
      AASM::StateMachine[self].roles
    end
    
    def aasm_events
      AASM::StateMachine[self].events
    end
    
    def aasm_states_for_select
      AASM::StateMachine[self].states.map { |state| state.for_select }
    end
    
  end

  # Instance methods
  def aasm_current_state
    return @aasm_current_state if @aasm_current_state

    if self.respond_to?(:aasm_read_state) || self.private_methods.include?('aasm_read_state')
      @aasm_current_state = aasm_read_state
    end
    return @aasm_current_state if @aasm_current_state
    self.class.aasm_initial_state
  end

  def aasm_events_for_current_state
    aasm_events_for_state(aasm_current_state)
  end

  def aasm_events_for_state(state)
    events = self.class.aasm_events.values.select {|event| event.transitions_from_state?(state) }
    events.map {|event| event.name}
  end

  private
  def set_aasm_current_state_with_persistence(state)
    save_success = true
    if self.respond_to?(:aasm_write_state) || self.private_methods.include?('aasm_write_state')
      save_success = aasm_write_state(state)
    end
    self.aasm_current_state = state if save_success

    save_success
  end

  def aasm_current_state=(state)
    if self.respond_to?(:aasm_write_state_without_persistence) || self.private_methods.include?('aasm_write_state_without_persistence')
      aasm_write_state_without_persistence(state)
    end
    @aasm_current_state = state
  end

  def aasm_state_object_for_state(name)
    obj = self.class.aasm_states.find {|s| s == name}
    raise AASM::UndefinedState, "State :#{name} doesn't exist" if obj.nil?
    obj
  end

  def aasm_fire_event(name, persist, *args)
    args.unshift(nil) unless args.first.nil? or args.empty? or self.class.aasm_states.include?(args.first.to_sym)

    aasm_state_object_for_state(aasm_current_state).call_action(:exit, self)

    new_state = self.class.aasm_events[name].fire(self, *args)
    
    unless new_state.nil?
      aasm_state_object_for_state(new_state).call_action(:enter, self)
      
      persist_successful = true
      if persist
        persist_successful = set_aasm_current_state_with_persistence(new_state)
        self.class.aasm_events[name].execute_success_callback(self) if persist_successful
      else
        self.aasm_current_state = new_state
      end

      if persist_successful 
        self.aasm_event_fired(self.aasm_current_state, new_state) if self.respond_to?(:aasm_event_fired)
      else
        self.aasm_event_failed(name) if self.respond_to?(:aasm_event_failed)
      end

      persist_successful
    else
      if self.respond_to?(:aasm_event_failed)
        self.aasm_event_failed(name)
      end
      
      false
    end
  end
end

module StagedAASM
  def self.Version
    '2.0.3'
  end

  class InvalidTransition < RuntimeError
  end
  
  def self.included(base) #:nodoc:
    # TODO - need to ensure that a machine is being created because
    # AASM was either included or arrived at via inheritance.  It
    # cannot be both.
    base.extend StagedAASM::ClassMethods
  end

  module ClassMethods

    def aasm_is_staged
      AASM::StateMachine[self].config.is_staged = true
    end
    
    def aasm_admin_roles(*args)
      sm = AASM::StateMachine[self]
      args.each do |arg|
        sm.admin_roles << arg if sm.roles.include?(arg)
      end
    end
    
    def aasm_staging_roles(*args)
      sm = AASM::StateMachine[self]
      args.each do |arg|
        sm.staging_roles << arg if sm.roles.include?(arg)
      end
    end
    
    def admin_roles
      AASM::StateMachine[self].admin_roles
    end
    
    def staging_roles
      AASM::StateMachine[self].staging_roles
    end
    
    def aasm_staged_event(name, options = {}, &block)
      sm = AASM::StateMachine[self]
      
      unless sm.events.has_key?(name)
        sm.events[name] = AASM::SupportingClasses::StagedEvent.new(name, options.merge({:admin_roles => sm.admin_roles, :staging_roles => sm.staging_roles}), &block)
      end
      
      define_method("#{name.to_s}!") do |*args|
        aasm_fire_event(name, true, *args)
      end
      
      define_method("#{name.to_s}") do |*args|
        aasm_fire_event(name, false, *args)
      end
    end
  end
end