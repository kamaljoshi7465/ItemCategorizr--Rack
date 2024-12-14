require 'sequel'
require 'dotenv/load'

DB = Sequel.connect(ENV['DATABASE_URL'])

DB.alter_table :items do
  add_foreign_key :category_id, :categories, null: true
end
