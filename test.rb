# frozen_string_literal: true

# This is a test schema.rb file to demonstrate the cop functionality

create_table 'applications', force: :cascade do |t|
  t.string 'name'
  t.timestamps
end

create_table 'companies', id: :integer, force: :cascade do |t|
  t.string 'name'
  t.timestamps
end

create_table 'users', id: :bigint, force: :cascade do |t|
  t.string 'email'
  t.timestamps
end

create_table 'device_settings', force: :cascade do |t|
  t.integer 'application_id'  # ← This should trigger a warning
  t.integer 'company_id'      # ← This should NOT trigger a warning (company has integer id)
  t.integer 'user_id'         # ← This should trigger a warning
  t.string 'setting_name'
  t.timestamps
end

create_table 'profiles', force: :cascade do |t|
  t.integer 'user_id'         # ← This should trigger a warning
  t.string 'bio'
  t.timestamps
end
