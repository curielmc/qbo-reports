module Api
  module V1
    module Admin
      class InvitationsController < AdminController
        def index
          invitations = Invitation.includes(:company).order(created_at: :desc)
          render json: invitations.map { |inv|
            {
              id: inv.id,
              email: inv.email,
              company_name: inv.company&.name,
              role: inv.role,
              token: inv.token,
              accepted_at: inv.accepted_at,
              expired: inv.expires_at && inv.expires_at < Time.current,
              created_at: inv.created_at
            }
          }
        end

        def create
          invitation = Invitation.new(invitation_params)
          invitation.invited_by = current_user
          invitation.token = SecureRandom.urlsafe_base64(32)
          invitation.expires_at = 7.days.from_now

          if invitation.save
            # TODO: Send invitation email via ActionMailer
            render json: { 
              id: invitation.id, 
              token: invitation.token,
              link: "#{request.base_url}/invite/#{invitation.token}",
              message: 'Invitation created' 
            }, status: :created
          else
            render json: { errors: invitation.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          invitation = Invitation.find(params[:id])
          invitation.destroy
          render json: { message: 'Invitation deleted' }
        end

        def resend
          invitation = Invitation.find(params[:id])
          invitation.update!(expires_at: 7.days.from_now)
          # TODO: Resend email
          render json: { message: 'Invitation resent' }
        end

        private

        def invitation_params
          params.require(:invitation).permit(:email, :company_id, :role)
        end
      end
    end
  end
end
