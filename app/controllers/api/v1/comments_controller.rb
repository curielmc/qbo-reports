module Api
  module V1
    class CommentsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company
      before_action :require_internal_access!
      before_action :set_commentable

      # GET /api/v1/companies/:company_id/comments
      # GET /api/v1/companies/:company_id/transactions/:transaction_id/comments
      # GET /api/v1/companies/:company_id/journal_entries/:journal_entry_id/comments
      def index
        comments = @commentable.comments
          .where(company: @company)
          .includes(:user, :mentions)
          .chronological

        render json: {
          comments: comments.map { |c| serialize_comment(c) },
          commentable_type: @commentable.class.name,
          commentable_id: @commentable.id
        }
      end

      # POST /api/v1/companies/:company_id/comments
      # POST /api/v1/companies/:company_id/transactions/:transaction_id/comments
      # POST /api/v1/companies/:company_id/journal_entries/:journal_entry_id/comments
      def create
        comment = @company.comments.build(
          user: current_user,
          commentable: @commentable,
          body: params[:body]
        )

        if comment.save
          render json: { comment: serialize_comment(comment.reload) }, status: :created
        else
          render json: { errors: comment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/companies/:company_id/comments/:id
      def destroy
        comment = @company.comments.find(params[:id])

        # Only the author or admins can delete
        unless comment.user_id == current_user.id || current_user.global_access?
          return render json: { error: 'Not authorized' }, status: :forbidden
        end

        comment.destroy
        render json: { success: true }
      end

      # GET /api/v1/companies/:company_id/comments/mentionable_users
      # Only returns internal team members (not clients/viewers)
      def mentionable_users
        users = User.where(role: %w[executive manager advisor])
          .or(User.where(id: @company.company_users.where(role: %w[owner bookkeeper editor]).select(:user_id)))
          .distinct
          .select(:id, :first_name, :last_name, :email, :role)

        render json: {
          users: users.map { |u|
            {
              id: u.id,
              first_name: u.first_name,
              last_name: u.last_name,
              name: "#{u.first_name} #{u.last_name}".strip,
              email: u.email,
              role: u.role
            }
          }
        }
      end

      # GET /api/v1/companies/:company_id/comments/recent
      def recent
        comments = @company.comments
          .includes(:user, :mentions, :commentable)
          .recent
          .limit(params[:limit] || 20)

        render json: {
          comments: comments.map { |c|
            serialize_comment(c).merge(
              commentable_type: c.commentable_type,
              commentable_id: c.commentable_id,
              commentable_label: commentable_label(c)
            )
          }
        }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end

      # Comments are internal-only: executives, managers, advisors, and
      # company-level owners/bookkeepers/editors can access them.
      # Clients and viewers cannot see internal comments.
      def require_internal_access!
        return if current_user.global_access? # executive, manager
        return if current_user.advisor? && current_user.companies.include?(@company)
        return if current_user.can_edit_in?(@company)

        render json: { error: 'Internal comments are not available for your role' }, status: :forbidden
      end

      def set_commentable
        if params[:transaction_id]
          account_ids = @company.accounts.pluck(:id)
          @commentable = AccountTransaction.where(account_id: account_ids).find(params[:transaction_id])
        elsif params[:journal_entry_id]
          @commentable = @company.journal_entries.find(params[:journal_entry_id])
        else
          @commentable = @company
        end
      end

      def serialize_comment(comment)
        {
          id: comment.id,
          body: comment.body,
          user: {
            id: comment.user.id,
            first_name: comment.user.first_name,
            last_name: comment.user.last_name,
            name: "#{comment.user.first_name} #{comment.user.last_name}".strip,
            email: comment.user.email
          },
          mentions: comment.mentions.map { |m|
            {
              id: m.id,
              user_id: m.user_id
            }
          },
          created_at: comment.created_at,
          is_author: comment.user_id == current_user.id
        }
      end

      def commentable_label(comment)
        case comment.commentable_type
        when 'Company'
          comment.commentable&.name
        when 'AccountTransaction'
          txn = comment.commentable
          txn ? "#{txn.description} (#{txn.date})" : 'Transaction'
        when 'JournalEntry'
          je = comment.commentable
          je ? "#{je.memo} (#{je.entry_date})" : 'Journal Entry'
        else
          comment.commentable_type
        end
      end
    end
  end
end
