module Api
  module V1
    class BookkeeperController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!

      # GET /api/v1/bookkeeper/dashboard
      # Multi-client overview with health scores
      def dashboard
        assistant = BookkeeperAiAssistant.new(current_user)
        clients = assistant.client_health_scores

        tasks = BookkeeperTask.where(assigned_to: current_user).open_tasks.by_priority.limit(20)

        render json: {
          clients: clients,
          tasks: tasks.map { |t| format_task(t) },
          stats: {
            total_clients: clients.size,
            healthy: clients.count { |c| c[:grade].in?(%w[A B]) },
            needs_attention: clients.count { |c| c[:grade].in?(%w[D F]) },
            open_tasks: BookkeeperTask.where(assigned_to: current_user).open_tasks.count,
            overdue_tasks: BookkeeperTask.where(assigned_to: current_user).overdue.count
          }
        }
      end

      # GET /api/v1/bookkeeper/tasks
      # Full task queue
      def tasks
        tasks = BookkeeperTask.where(assigned_to: current_user)
        tasks = tasks.where(status: params[:status]) if params[:status]
        tasks = tasks.where(task_type: params[:type]) if params[:type]
        tasks = tasks.where(company_id: params[:company_id]) if params[:company_id]
        tasks = tasks.by_priority.order(due_date: :asc).limit(params[:limit] || 50)

        render json: tasks.map { |t| format_task(t) }
      end

      # PATCH /api/v1/bookkeeper/tasks/:id
      def update_task
        task = BookkeeperTask.where(assigned_to: current_user).find(params[:id])

        case params[:action_type]
        when 'start' then task.start!
        when 'complete' then task.complete!(current_user)
        when 'dismiss' then task.dismiss!
        end

        render json: format_task(task)
      end

      # POST /api/v1/bookkeeper/generate_tasks
      # AI scans all clients and creates new tasks
      def generate_tasks
        assistant = BookkeeperAiAssistant.new(current_user)
        count = assistant.generate_tasks
        render json: { tasks_created: count }
      end

      # GET /api/v1/bookkeeper/anomalies/:company_id
      def anomalies
        company = current_user.accessible_companies.find(params[:company_id])
        assistant = BookkeeperAiAssistant.new(current_user)
        render json: assistant.detect_anomalies(company)
      end

      # GET /api/v1/bookkeeper/categorization/:company_id
      # Smart batch categorization suggestions
      def categorization
        company = current_user.accessible_companies.find(params[:company_id])
        assistant = BookkeeperAiAssistant.new(current_user)
        render json: assistant.smart_categorize(company)
      end

      # POST /api/v1/bookkeeper/categorize_batch
      # Apply categorization to multiple transactions at once
      def categorize_batch
        company = current_user.accessible_companies.find(params[:company_id])
        applied = 0

        (params[:categorizations] || []).each do |cat|
          txn_ids = cat['transaction_ids'] || []
          coa_id = cat['category_id']
          next unless coa_id

          coa = company.chart_of_accounts.find_by(id: coa_id)
          next unless coa

          company.transactions.where(id: txn_ids).update_all(chart_of_account_id: coa.id)
          applied += txn_ids.size

          # Create journal entries for newly categorized
          txn_ids.each do |tid|
            txn = company.transactions.find_by(id: tid)
            next unless txn
            BookkeeperAi.new(company, current_user).send(:create_journal_entry, txn) rescue nil
          end
        end

        AuditLog.record!(
          company: company, user: current_user,
          action: 'batch_categorize',
          changes: { transactions_categorized: applied }
        )

        render json: { applied: applied }
      end

      # GET /api/v1/bookkeeper/vendors/:company_id
      def vendors
        company = current_user.accessible_companies.find(params[:company_id])
        assistant = BookkeeperAiAssistant.new(current_user)
        render json: assistant.vendor_summary(company)
      end

      # GET /api/v1/bookkeeper/month_end/:company_id
      def month_end
        company = current_user.accessible_companies.find(params[:company_id])
        period = params[:period] ? Date.parse(params[:period]) : 1.month.ago.beginning_of_month
        close = MonthEndClose.open_or_create(company, current_user, period)

        render json: {
          id: close.id,
          period: close.period,
          status: close.status,
          progress: close.progress,
          checklist: close.checklist,
          closed_at: close.closed_at
        }
      end

      # PATCH /api/v1/bookkeeper/month_end/:company_id/check
      def month_end_check
        company = current_user.accessible_companies.find(params[:company_id])
        period = params[:period] ? Date.parse(params[:period]) : 1.month.ago.beginning_of_month
        close = MonthEndClose.open_or_create(company, current_user, period)

        if params[:uncheck]
          close.uncheck!(params[:step])
        else
          close.check!(params[:step], current_user)
        end

        render json: {
          progress: close.progress,
          status: close.status,
          checklist: close.checklist
        }
      end

      # POST /api/v1/bookkeeper/month_end/:company_id/close
      def month_end_close
        company = current_user.accessible_companies.find(params[:company_id])
        period = params[:period] ? Date.parse(params[:period]) : 1.month.ago.beginning_of_month
        close = MonthEndClose.open_or_create(company, current_user, period)

        unless close.all_complete?
          return render json: { error: 'All checklist items must be completed first' }, status: :unprocessable_entity
        end

        close.close!(current_user)

        AuditLog.record!(
          company: company, user: current_user,
          action: 'month_end_closed',
          resource: close,
          changes: { period: close.period.to_s }
        )

        render json: { message: "#{close.period.strftime('%B %Y')} is closed!", status: close.status }
      end

      private

      def format_task(t)
        {
          id: t.id,
          company_id: t.company_id,
          company_name: t.company.name,
          type: t.task_type,
          priority: t.priority,
          status: t.status,
          title: t.title,
          description: t.description,
          estimated_minutes: t.estimated_minutes,
          due_date: t.due_date,
          metadata: t.metadata,
          created_at: t.created_at
        }
      end
    end
  end
end
