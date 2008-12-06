describe Conversation, 'description' do
  it '.aasm_states should contain all of the states' do
    Conversation.aasm_states.should == [:needs_attention, :read, :closed, :awaiting_response, :junk]
  end
  
  it '.aasm_roles should contain all of the roles' do
    Conversation.aasm_roles.should == [:user, :content_manager, :admin]
  end
end
