actions :wait

default_action :nothing

attribute :role, :kind_of => String, :name_attribute => true
attribute :delay, :kind_of => Fixnum, :default => 10
attribute :timeout, :kind_of => Fixnum, :default => 5