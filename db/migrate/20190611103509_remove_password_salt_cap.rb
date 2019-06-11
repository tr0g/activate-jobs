class RemovePasswordSaltCap < ActiveRecord::Migration
  def self.up
    change_column :users, :password_salt, :string, :limit => nil
    change_column :users, :crypted_password, :string, :limit => nil
  end
end