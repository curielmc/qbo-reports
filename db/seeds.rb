# Default admin user
if User.count == 0
  User.create!(
    email: 'martin@myecfo.com',
    password: 'etnH02T!%Pbi',
    password_confirmation: 'etnH02T!%Pbi',
    first_name: 'Martin',
    last_name: 'Curiel',
    role: 'admin'
  )
  puts "Created admin user: martin@myecfo.com"
end
