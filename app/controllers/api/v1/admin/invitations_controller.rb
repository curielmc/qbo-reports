module Api
  module V1
    module Admin
      class InvitationsController < AdminController
        # GET /api/v1/admin/invitations
        def index
          invitations = Invitation.includes(:household, :invited_by).order(created_at: :desc)
          render json: invitations.map { |inv| serialize(inv) }
        end

        # POST /api/v1/admin/invitations
        def create
          invitation = Invitation.new(invitation_params)
          invitation.invited_by = current_user

          if invitation.save
            # Send invitation email
            InvitationMailer.invite(invitation).deliver_later if defined?(InvitationMailer)
            render json: serialize(invitation), status: :created
          else
            render json: { errors: invitation.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # POST /api/v1/admin/invitations/:id/resend
        def resend
          invitation = Invitation.find(params[:id])
          invitation.update!(expires_at: 7.days.from_now)
          InvitationMailer.invite(invitation).deliver_later if defined?(InvitationMailer)
          render json: { message: 'Invitation resent', invitation: serialize(invitation) }
        end

        # DELETE /api/v1/admin/invitations/:id
        def destroy
          invitation = Invitation.find(params[:id])
          invitation.destroy
          render json: { message: 'Invitation cancelled' }
        end

        private

        def invitation_params
          params.require(:invitation).permit(:email, :first_name, :last_name, :role, :household_id, :personal_message)
        end

        def serialize(inv)
          {
            id: inv.id,
            email: inv.email,
            first_name: inv.first_name,
            last_name: inv.last_name,
            role: inv.role,
            household_name: inv.household&.name,
            household_id: inv.household_id,
            invited_by: inv.invited_by&.email,
            status: inv.accepted? ? 'accepted' : inv.expired? ? 'expired' : 'pending',
            invite_url: inv.invite_url,
            personal_message: inv.personal_message,
            expires_at: inv.expires_at,
            accepted_at: inv.accepted_at,
            created_at: inv.created_at
          }
        end
      end
    end
  end
end
