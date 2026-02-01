ActiveAdmin.setup do |config|
  config.site_title = "QBO Reports Admin"
  config.authentication_method = :authenticate_admin_user!
  config.current_user_method = :current_admin_user
  config.logout_link_path = :destroy_admin_user_session_path
  config.root_to = 'dashboard#index'
  config.batch_actions = true
  config.filter_fallbacks = { contains: :cont, equals: :eq, starts_with: :start, ends_with: :end }
  config.localize_format = :long
  config.include_default_association_filters = true
  config.comments = true
  config.comments_registration_name = 'AdminComment'
end
