require_dependency 'redmine/scm/adapters/abstract_adapter'

module RedminePulls
  module Patches
    module AbstractAdapterPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable # Send unloadable so it will not be unloaded in development
        end
      end

      module InstanceMethods
        def mergable(commit_base, commit_head)
          false
        end
      end
    end
  end
end

unless Redmine::Scm::Adapters::AbstractAdapter.included_modules.include?(RedminePulls::Patches::AbstractAdapterPatch)
  Redmine::Scm::Adapters::AbstractAdapter.send(:include, RedminePulls::Patches::AbstractAdapterPatch)
end
