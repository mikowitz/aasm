require File.join(File.dirname(__FILE__), 'state_transition')

module AASM
  module SupportingClasses
    class Event
      attr_reader :name, :success
      
      def initialize(name, options = {}, &block)
        @name = name
        @success = options[:success]
        @transitions = []
        instance_eval(&block) if block
      end

      def fire(obj, to_state=nil, *args)
        role = !AASM::StateMachine[obj.class].nil? ? (obj.class.aasm_roles & args.flatten).first || obj.class.aasm_default_role : nil

        second_arg = obj.class.respond_to?(:aasm_roles) ? obj.class.aasm_roles : nil
        transitions = @transitions.select { |t| t.from == obj.aasm_current_state and role_truth(t.for || second_arg, role) }
        raise AASM::InvalidTransition, "Event '#{name}' cannot transition from '#{obj.aasm_current_state}' as #{role.to_s}" if transitions.size == 0

        next_state = nil
        transitions.each do |transition|
          next if to_state and !Array(transition.to).include?(to_state)
          if transition.perform(obj)
            next_state = to_state || Array(transition.to).first
            transition.execute(obj, *args)
            break
          end
        end
        next_state
      end
      
      def transitions_from_state?(state)
        @transitions.any? { |t| t.from == state }
      end
      
      def execute_success_callback(obj)
        case success
        when String, Symbol:
          obj.send(success)
        when Array:
          success.each { |meth| obj.send(meth) }
        when Proc:
          success.call(obj)
        end
      end

      private
      def transitions(trans_opts)
        Array(trans_opts[:from]).each do |s|
          @transitions << SupportingClasses::StateTransition.new(trans_opts.merge({:from => s.to_sym}))
        end
      end
      
      def role_truth(trans_for, role)
        role.nil? ? true : trans_for.is_a?(Symbol) ? trans_for == role : trans_for.include?(role)
      end
    end
  end
end
