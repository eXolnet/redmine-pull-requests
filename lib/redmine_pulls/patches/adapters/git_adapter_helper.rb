require_dependency 'redmine/scm/adapters/git_adapter'

module RedminePulls
  module Patches
    module Adapters
      module GitAdapterPatch
        extend ActiveSupport::Concern

        included do
          include InstanceMethods
        end
        
        module InstanceMethods
          def create_branch(identifier, commit)
            cmd_args = %w|update-ref|
            cmd_args << 'refs/heads/' + identifier
            cmd_args << commit

            git_cmd(cmd_args)

            true
          rescue Redmine::Scm::Adapters::AbstractAdapter::ScmCommandAborted
            false
          end

          def delete_branch(identifier)
            cmd_args = %w|update-ref -d|
            cmd_args << 'refs/heads/' + identifier

            git_cmd(cmd_args)

            true
          rescue Redmine::Scm::Adapters::AbstractAdapter::ScmCommandAborted
            false
          end

          def merge_base(commit_base, commit_head)
            cmd_args = %w|merge-base|
            cmd_args << commit_base
            cmd_args << commit_head

            git_cmd_output(cmd_args)
          rescue Redmine::Scm::Adapters::AbstractAdapter::ScmCommandAborted
            nil
          end

          def mergable?(commit_base, commit_head)
            merge_result = merge_tree(commit_base, commit_head)

            # Split the regex to avoid conflict detection when working with this file
            regex = Regexp.new("<<<" + "<<<<.*=======.*>>>>>>>", Regexp::MULTILINE)

            ! regex.match(merge_result)
          end

          def merge(commit_base, commit_head, options = {})
            # Retrieve the current commit to avoid overwriting to avoid
            # losing changes that may arrive while we're merging
            old_ref = revision(commit_base)
            base_ref = merge_base(commit_base, commit_head)

            # Make sure the tree index is empty
            git_cmd_output(%w|read-tree --empty|)

            # Load the tree index with the result of a 3-way merge
            # between our fork point, the base branch and the head branch
            # $ git read-tree -i -m base branch1 branch2
            cmd_args = %w|read-tree -i -m|
            cmd_args << base_ref
            cmd_args << commit_base
            cmd_args << commit_head
            git_cmd_output(cmd_args)

            # Write a tree object with the loaded state
            # $ git write-tree
            write_tree = git_cmd_output(%w|write-tree|)

            raise 'Invalid or missing hash' unless write_tree

            # Create a commit object pointing to the created tree object
            # $ COMMIT=$(git commit-tree $(git write-tree) -p branch1 -p branch2 < commit message)
            cmd_args = %w||
            cmd_args << '-c' << "user.name=#{options[:author_name]}" if options[:author_name]
            cmd_args << '-c' << "user.email=#{options[:author_email]}" if options[:author_email]
            cmd_args << 'commit-tree'
            cmd_args << write_tree
            cmd_args << '-p' << commit_base
            cmd_args << '-p' << commit_head
            cmd_args << '-m' << options[:message] || "Merge #{commit_head} into #{commit_base}"
            commit_hash = git_cmd_output(cmd_args)

            raise 'Invalid or missing hash' unless commit_hash

            # Update the base branch to point to our new commit
            # $ git update-ref mergedbranch $COMMIT
            cmd_args = %w|update-ref|
            cmd_args << "refs/heads/#{commit_base}"
            cmd_args << commit_hash
            cmd_args << old_ref
            git_cmd_output(cmd_args)

            commit_hash
          end

          def revision(identifier)
            cmd_args = %w|rev-parse --verify|
            cmd_args << identifier

            git_cmd_output(cmd_args)
          end

          def is_ancestor?(expected_ancestor, expected_descendant)
            ancestor_revision = revision(expected_ancestor)
            merge_base = merge_base(expected_ancestor, expected_descendant)

            ancestor_revision == merge_base
          end

          def conflicting_files(commit_base, commit_head)
            merge_result = merge_tree(commit_base, commit_head)

            matches = merge_result.split(/^\s+their\s+\d+\s+[a-f0-9]+\s(.+)$/)

            (1..matches.size - 1).step(2).map{ |i| matches[i] }.uniq.sort
          end

          private

          def git_cmd_output(command, options = {})
            result = nil

            git_cmd(command, options) { |io| io.binmode; result = io.read }

            result&.strip
          end

          def merge_tree(commit_base, commit_head)
            merge_base = merge_base(commit_base, commit_head)

            # We need a common ancestor to perform a merge
            return nil unless merge_base

            cmd_args = %w|merge-tree|
            cmd_args << merge_base
            cmd_args << commit_base
            cmd_args << commit_head

            git_cmd_output(cmd_args)
          end
        end
      end
    end
  end
end

unless Redmine::Scm::Adapters::GitAdapter.included_modules.include?(RedminePulls::Patches::Adapters::GitAdapterPatch)
  Redmine::Scm::Adapters::GitAdapter.send(:include, RedminePulls::Patches::Adapters::GitAdapterPatch)
end
