module Api
  module V1
    class JournalEntriesController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/journal_entries
      def index
        entries = @company.journal_entries.includes(:journal_lines, journal_lines: :chart_of_account)
        entries = entries.where(entry_type: params[:type]) if params[:type]
        entries = entries.where(posted: params[:posted] == 'true') if params[:posted]
        entries = entries.by_date(params[:start_date], params[:end_date]) if params[:start_date] && params[:end_date]
        entries = entries.order(entry_date: :desc, created_at: :desc).limit(params[:limit] || 50)

        render json: entries.map { |e| format_entry(e) }
      end

      # GET /api/v1/companies/:company_id/journal_entries/:id
      def show
        entry = @company.journal_entries.includes(journal_lines: :chart_of_account).find(params[:id])
        render json: format_entry(entry)
      end

      # POST /api/v1/companies/:company_id/journal_entries
      # Create manual journal entry or adjustment
      def create
        entry = @company.journal_entries.build(
          entry_date: params[:entry_date] || Date.current,
          memo: params[:memo],
          source: 'manual',
          entry_type: params[:entry_type] || 'adjusting',
          reference_number: params[:reference_number],
          posted: params[:posted] != false
        )

        (params[:lines] || []).each do |line|
          coa = @company.chart_of_accounts.find(line[:chart_of_account_id])
          entry.journal_lines.build(
            chart_of_account: coa,
            debit: line[:debit] || 0,
            credit: line[:credit] || 0,
            memo: line[:memo]
          )
        end

        if entry.save
          AuditLog.record!(
            company: @company, user: current_user,
            action: "journal_entry_#{params[:entry_type] || 'adjusting'}",
            resource: entry,
            changes: { lines: params[:lines]&.size, total: entry.journal_lines.sum(:debit) }
          )
          render json: format_entry(entry), status: :created
        else
          render json: { errors: entry.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/companies/:company_id/journal_entries/:id
      def update
        entry = @company.journal_entries.find(params[:id])

        # Can't edit posted entries directly — need to reverse
        if entry.posted? && params[:lines]
          return render json: { error: 'Posted entries cannot be edited. Create a reversing entry instead.' }, status: :unprocessable_entity
        end

        entry.update!(
          entry_date: params[:entry_date] || entry.entry_date,
          memo: params[:memo] || entry.memo,
          reference_number: params[:reference_number] || entry.reference_number
        )

        if params[:lines]
          entry.journal_lines.destroy_all
          (params[:lines] || []).each do |line|
            coa = @company.chart_of_accounts.find(line[:chart_of_account_id])
            entry.journal_lines.create!(
              chart_of_account: coa,
              debit: line[:debit] || 0,
              credit: line[:credit] || 0,
              memo: line[:memo]
            )
          end
        end

        render json: format_entry(entry.reload)
      end

      # POST /api/v1/companies/:company_id/journal_entries/:id/post
      def post_entry
        entry = @company.journal_entries.find(params[:id])
        unless entry.balanced?
          return render json: { error: "Entry doesn't balance" }, status: :unprocessable_entity
        end

        entry.update!(posted: true, approved_by_id: current_user.id, approved_at: Time.current)
        render json: format_entry(entry)
      end

      # POST /api/v1/companies/:company_id/journal_entries/:id/reverse
      def reverse
        entry = @company.journal_entries.includes(journal_lines: :chart_of_account).find(params[:id])

        reversal = @company.journal_entries.build(
          entry_date: params[:reversal_date] || Date.current,
          memo: "REVERSAL: #{entry.memo}",
          source: 'manual',
          entry_type: 'reversing',
          posted: true,
          reversing_entry_id: entry.id
        )

        # Flip all debits/credits
        entry.journal_lines.each do |line|
          reversal.journal_lines.build(
            chart_of_account: line.chart_of_account,
            debit: line.credit,
            credit: line.debit,
            memo: "Reversal: #{line.memo}"
          )
        end

        reversal.save!
        entry.update!(reversed: true)

        AuditLog.record!(
          company: @company, user: current_user,
          action: 'journal_entry_reversed',
          resource: entry,
          changes: { reversal_id: reversal.id }
        )

        render json: { original: format_entry(entry), reversal: format_entry(reversal) }
      end

      # DELETE /api/v1/companies/:company_id/journal_entries/:id
      def destroy
        entry = @company.journal_entries.find(params[:id])
        if entry.posted?
          return render json: { error: 'Cannot delete posted entries. Create a reversing entry instead.' }, status: :unprocessable_entity
        end
        entry.destroy!
        render json: { message: 'Entry deleted' }
      end

      # ============================================
      # RECURRING ENTRIES
      # ============================================

      # GET /api/v1/companies/:company_id/journal_entries/recurring
      def recurring_index
        entries = @company.recurring_entries.order(next_run_date: :asc)
        entries = entries.active if params[:active_only]

        render json: entries.map { |r|
          {
            id: r.id, name: r.name, memo: r.memo, frequency: r.frequency,
            next_run_date: r.next_run_date, end_date: r.end_date,
            active: r.active, auto_post: r.auto_post,
            times_run: r.times_run, lines: r.lines
          }
        }
      end

      # POST /api/v1/companies/:company_id/journal_entries/recurring
      def create_recurring
        recurring = @company.recurring_entries.create!(
          created_by: current_user,
          name: params[:name],
          memo: params[:memo],
          frequency: params[:frequency] || 'monthly',
          start_date: params[:start_date] || Date.current,
          end_date: params[:end_date],
          next_run_date: params[:start_date] || Date.current,
          auto_post: params[:auto_post] || false,
          lines: params[:lines]
        )
        render json: { id: recurring.id, name: recurring.name, next_run_date: recurring.next_run_date }
      end

      # POST /api/v1/companies/:company_id/journal_entries/recurring/:id/run
      def run_recurring
        recurring = @company.recurring_entries.find(params[:id])
        entry = recurring.run!
        render json: { entry: format_entry(entry), next_run: recurring.next_run_date }
      end

      # POST /api/v1/companies/:company_id/journal_entries/process_recurring
      def process_recurring
        count = RecurringEntry.process_due(@company)
        render json: { entries_created: count }
      end

      # ============================================
      # AI SUGGESTIONS
      # ============================================

      # GET /api/v1/companies/:company_id/journal_entries/suggestions
      # AI analyzes books and suggests adjustments
      def suggestions
        ai = JournalEntryAi.new(@company, current_user)
        period_end = params[:period_end] ? Date.parse(params[:period_end]) : Date.current.end_of_month
        suggestions = ai.suggest_adjustments(period_end)

        render json: {
          period: period_end.strftime('%B %Y'),
          suggestions: suggestions.map { |s|
            {
              type: s[:type],
              confidence: s[:confidence],
              memo: s[:memo],
              amount: s[:amount],
              reasoning: s[:reasoning],
              lines: s[:lines],
              entry_date: s[:entry_date],
              source: s[:source]
            }
          },
          high_confidence: suggestions.count { |s| s[:confidence] >= 80 },
          total: suggestions.size
        }
      end

      # POST /api/v1/companies/:company_id/journal_entries/auto_adjust
      # Create all high-confidence AI suggestions as draft entries
      def auto_adjust
        ai = JournalEntryAi.new(@company, current_user)
        period_end = params[:period_end] ? Date.parse(params[:period_end]) : Date.current.end_of_month
        created = ai.auto_adjust(period_end)

        UsageMeter.new(@company, current_user).track('auto_adjust',
          summary: "AI auto-adjust: #{created.size} entries for #{period_end.strftime('%B %Y')}")

        render json: {
          created: created,
          message: "Created #{created.size} adjusting entries as drafts. Review and post them."
        }
      end

      # POST /api/v1/companies/:company_id/journal_entries/create_from_suggestion
      def create_from_suggestion
        ai = JournalEntryAi.new(@company, current_user)
        entry = ai.create_from_suggestion(
          type: params[:type],
          confidence: params[:confidence],
          memo: params[:memo],
          amount: params[:amount].to_f,
          lines: params[:lines]&.map { |l| l.to_unsafe_h.symbolize_keys } || [],
          entry_date: params[:entry_date] ? Date.parse(params[:entry_date]) : Date.current
        )

        if entry
          render json: format_entry(entry)
        else
          render json: { error: 'Could not create entry' }, status: :unprocessable_entity
        end
      end

      # ============================================
      # TEMPLATES
      # ============================================

      # GET /api/v1/companies/:company_id/journal_entries/templates
      def templates
        JournalTemplate.seed_system_templates(@company) unless @company.journal_templates.exists?
        templates = @company.journal_templates.order(:name)
        render json: templates.map { |t|
          { id: t.id, name: t.name, description: t.description, entry_type: t.entry_type,
            lines: t.lines, system: t.system_template }
        }
      end

      # POST /api/v1/companies/:company_id/journal_entries/from_template
      def from_template
        template = @company.journal_templates.find(params[:template_id])
        amount = params[:amount].to_f

        entry = @company.journal_entries.build(
          entry_date: params[:entry_date] || Date.current,
          memo: params[:memo] || template.name,
          source: 'template',
          entry_type: template.entry_type,
          posted: false
        )

        (template.lines || []).each do |line|
          # Resolve account — use provided account_id or find by name
          coa = if line['chart_of_account_id']
            @company.chart_of_accounts.find_by(id: line['chart_of_account_id'])
          elsif params["account_for_#{line['account_name']}"]
            @company.chart_of_accounts.find_by(id: params["account_for_#{line['account_name']}"])
          end
          next unless coa

          debit = line['side'] == 'debit' ? amount : 0
          credit = line['side'] == 'credit' ? amount : 0

          entry.journal_lines.build(
            chart_of_account: coa,
            debit: debit,
            credit: credit,
            memo: line['memo']
          )
        end

        if entry.save
          render json: format_entry(entry)
        else
          render json: { errors: entry.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end

      def format_entry(entry)
        {
          id: entry.id,
          entry_date: entry.entry_date,
          memo: entry.memo,
          entry_type: entry.entry_type,
          source: entry.source,
          reference_number: entry.reference_number,
          posted: entry.posted,
          reversed: entry.reversed,
          balanced: entry.balanced?,
          total_debits: entry.journal_lines.sum(:debit).round(2),
          total_credits: entry.journal_lines.sum(:credit).round(2),
          lines: entry.journal_lines.map { |l|
            {
              id: l.id,
              account: l.chart_of_account.name,
              account_id: l.chart_of_account_id,
              account_type: l.chart_of_account.account_type,
              debit: l.debit,
              credit: l.credit,
              memo: l.memo
            }
          },
          created_at: entry.created_at
        }
      end
    end
  end
end
