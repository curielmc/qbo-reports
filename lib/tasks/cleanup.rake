namespace :cleanup do
  desc "Remove duplicate Ivy Education Advisors companies, keeping only the first one (if any)"
  task duplicate_companies: :environment do
    dupes = Company.where(name: "Ivy Education Advisors, LLC").order(:id)
    if dupes.count <= 1
      puts "No duplicates found. #{dupes.count} company with that name."
    else
      keep = dupes.first
      to_delete = dupes.where.not(id: keep.id)
      puts "Keeping company ##{keep.id} '#{keep.name}'"
      puts "Deleting #{to_delete.count} duplicates..."
      to_delete.each do |c|
        puts "  Destroying company ##{c.id} '#{c.name}' (#{c.accounts.count} accounts, #{c.account_transactions.count} transactions)"
        c.destroy!
      end
      puts "Done. #{to_delete.count} duplicates removed."
    end
  end
end
