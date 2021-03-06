require_dependency 'redmine/scm/adapters/abstract_adapter'

module RedminePulls
  module Patches
    module Adapters
      module AbstractAdapterPatch
        extend ActiveSupport::Concern

        included do
          include InstanceMethods
        end
        
        module InstanceMethods
          def create_branch(identifier, commit)
            false
          end

          def delete_branch(identifier)
            false
          end

          def merge_base(commit_base, commit_head)
            nil
          end

          def mergable?(commit_base, commit_head)
            false
          end

          def merge(commit_base, commit_head, options = {})
            nil
          end

          def revision(identifier)
            nil
          end

          def is_ancestor?(commit_ancestor, commit_descendant)
            false
          end

          def conflicting_files(commit_base, commit_head)
            nil
          end
        end
      end
    end
  end
end

unless Redmine::Scm::Adapters::AbstractAdapter.included_modules.include?(RedminePulls::Patches::Adapters::AbstractAdapterPatch)
  Redmine::Scm::Adapters::AbstractAdapter.send(:include, RedminePulls::Patches::Adapters::AbstractAdapterPatch)
end

