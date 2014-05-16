require 'submodel/version'

require 'active_support/all'

module Submodel
end

ActiveSupport.on_load(:active_record) do
  require 'submodel/active_record'
  ActiveRecord::Base.send(:include, Submodel::ActiveRecord)
end
