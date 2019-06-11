class UpdatePasswordsTo128Characters < ActiveRecord::Migration
  change_column :users, :crypted_password, :string, :limit => 128,
                :null => false, :default => ""

  change_column :users, :salt, :string, :limit => 128,
                :null => false, :default => ""
end
