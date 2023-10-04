class AddDirectoryToGlobusDestination < ActiveRecord::Migration[7.0]
  def up
    add_column :globus_destinations, :directory, :string

    # populate any missing directory values
    GlobusDestination.all.each do |dest|
      dest.directory = dest.created_at.strftime('%Y-%m-%d-%H-%M-%S-%L')
      dest.save
    end

    change_column_null :globus_destinations, :directory, false
  end

  def down
    drop_column :globus_destinations, :directory
  end
end
