require 'sequel'
require 'dotenv/load'

DB = Sequel.connect(ENV['DATABASE_URL'])

DB.create_table :items do
  primary_key :id
  String :name, null: false
  Float :price, null: false
  DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
  DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end
