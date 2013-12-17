namespace :activr do

  desc "Create the indexes"
  task :create_indexes => :environment do
    ::Rails.application.eager_load!

    Activr.setup

    Activr.storage.create_indexes do |index_name|
      puts "Created index: #{index_name}"
    end
  end

end
