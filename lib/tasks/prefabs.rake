namespace :prefabs do
  namespace :sugoi do
    desc "Upgrade existing Sugoi installations."
    task :upgrade => :environment do
      prefabs = Prefab.find_all_by_prefab_name "sugoi" 
      count = 0

      prefabs.each do |p|
        vars = p.config.customization.vars
        if !vars.include? :extralinks
          links = []
          %w(link1 link2 link3 link4).each do |l|
            if vars.include? l
              link = vars[l]
              links.push(link) unless link.text.nil? or link.url.nil? or link.url == "http://"
            end
          end

          puts "Updating prefab #{p.name} by #{p.journal.user.username}"

          p.config.customization.vars.delete(:link1)
          p.config.customization.vars.delete(:link2)
          p.config.customization.vars.delete(:link3)
          p.config.customization.vars.delete(:link4)
          p.config.customization.vars.extralinks = links

          # Just in case, create a backup of the old prefab file
          File.copy(p.config.filepath, p.config.filepath + ".bak")

          p.config.save
          p.save
          count += 1
        end
      end

      include ActionView::Helpers::TextHelper
      puts pluralize(count, "prefab") + " updated."
    end
  end
end
