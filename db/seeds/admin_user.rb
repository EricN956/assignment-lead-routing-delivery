admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
admin_password = ENV.fetch("ADMIN_PASSWORD", "password")

AdminUser.find_or_create_by!(email: admin_email) do |admin|
  admin.password = admin_password
  admin.password_confirmation = admin_password
end
