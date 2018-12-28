actions :wait

default_action :nothing

attribute :port, :kind_of => Fixnum
attribute :role, :kind_of => String, :name_attribute => true
attribute :delay, :kind_of => Fixnum, :default => 10
attribute :timeout, :kind_of => Fixnum, :default => 300