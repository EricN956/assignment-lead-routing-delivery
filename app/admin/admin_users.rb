ActiveAdmin.register AdminUser do
  menu priority: 3, label: "Admin Users"

  config.clear_action_items!
  config.batch_actions = false
  config.per_page = 10

  permit_params :email, :password, :password_confirmation

  filter :email
  filter :created_at

  action_item :new, only: :index do
    aa_new_button(new_resource_path, "Create Admin User")
  end

  action_item :show, only: :edit do
    aa_view_button(resource_path(resource))
  end

  action_item :edit, only: :show do
    aa_edit_button(edit_resource_path(resource))
  end

  action_item :destroy, only: [:show, :edit] do
    aa_delete_button(resource_path(resource))
  end

  index title: "Admin Users" do
    column "ID", :id
    column :email
    column("Role") { status_tag("administrator") }
    column("Status") { status_tag("active") }
    column :created_at

    column "" do |admin_user|
      content_tag :div, class: "aa-actions-group" do
        safe_join([
          aa_view_button(resource_path(admin_user)),
          aa_edit_button(edit_resource_path(admin_user)),
          aa_delete_button(resource_path(admin_user))
        ])
      end
    end
  end

  show title: proc { |admin_user| admin_user.email } do
    panel "Admin User Summary" do
      attributes_table_for resource do
        row :id
        row :email
        row("Role") { status_tag("administrator") }
        row("Status") { status_tag("active") }
        row :created_at
        row :updated_at
      end
    end
  end

  form do |f|
    f.semantic_errors

    f.inputs "Account Details" do
      f.input :email, input_html: { placeholder: "admin@example.com" }
      f.input :password, hint: "Leave blank unless changing the password."
      f.input :password_confirmation
    end

    f.actions do
      f.action :submit
      f.cancel_link
    end
  end
end
