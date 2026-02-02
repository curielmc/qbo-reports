class BoxSyncJobRunner < ApplicationJob
  queue_as :default

  def perform(company_id, user_id, sync_job_id)
    company = Company.find(company_id)
    user = User.find(user_id)
    sync_job = BoxSyncJob.find(sync_job_id)

    BoxSyncService.new(company, user, sync_job).run
  end
end
