module Api
  module V1
    class InvitationsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!, except: [:accept]
      before_action :set_company, except: [:accept]

      # POST /api/v1/companies/:company_id/invitations
      def create
        invitation = @company.invitations.create!(
          invited_by: current_user,
          email: params[:email],
          role: params[:role] || 'viewer'
        )

        # TODO: Send invitation email
        # InvitationMailer.invite(invitation).deliver_later

        AuditLog.record!(
          company: @company, user: current_user,
          action: 'invitation_sent', resource: invitation,
          changes: { email: params[:email], role: params[:role] }
        )

        render json: {
          invitation: {
            id: invitation.id,
            email: invitation.email,
            role: invitation.role,
            status: invitation.status,
            expires_at: invitation.expires_at,
            invite_url: "#{request.base_url}/invite/#{invitation.token}"
          }
        }
      end

      # GET /api/v1/companies/:company_id/invitations
      def index
        invitations = @company.invitations.order(created_at: :desc)
        render json: invitations.map { |i|
          {
            id: i.id,
            email: i.email,
            role: i.role,
            status: i.status,
            invited_by: i.invited_by.name,
            created_at: i.created_at,
            expires_at: i.expires_at
          }
        }
      end

      # POST /api/v1/invitations/:token/accept
      def accept
        invitation = Invitation.find_by!(token: params[:token])

        if invitation.expired?
          return render json: { error: 'Invitation has expired' }, status: :gone
        end

        if invitation.status != 'pending'
          return render json: { error: 'Invitation already used' }, status: :unprocessable_entity
        end

        # If user is logged in, accept directly
        if current_user
          invitation.accept!(current_user)
          render json: { message: "Welcome to #{invitation.company.name}!", company_id: invitation.company.id }
        else
          # Return invitation details for signup/login flow
          render json: {
            invitation: {
              email: invitation.email,
              company_name: invitation.company.name,
              role: invitation.role,
              requires_login: true
            }
          }
        end
      end

      # DELETE /api/v1/companies/:company_id/invitations/:id
      def destroy
        invitation = @company.invitations.find(params[:id])
        invitation.update!(status: 'revoked')
        render json: { message: 'Invitation revoked' }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end
    end
  end
end
