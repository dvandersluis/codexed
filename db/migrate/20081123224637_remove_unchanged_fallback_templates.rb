class RemoveUnchangedFallbackTemplates < ActiveRecord::Migration
  def self.up
    original_fallback = <<EOT
<html>
<head>
  <title>[journal_title] - [title]</title>
</head>
<body>
  <h1>[journal_title]</h1>
  <h2>[title]</h2>
  <p><b>Posted on [time]</b></p>
  [body]
  <br />
  <p>[prev link]&nbsp;[curr link]&nbsp;[next link]</p>
</body>
</html>
EOT
    original_fallback.strip!
    i = 0
    templates = Template.find(:all, :include => :journal, :conditions => { :type => "Template", :name => "main" })
    Template.transaction do
      for template in templates
        if content = template.raw_content.strip.gsub(/\r\n/, "\n") and content == original_fallback
          i += 1
          template.destroy
          puts "Removed template ##{template.id}"
        end
      end
    end
    puts "\nNumber of templates removed: #{i}"
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration, "No way to revert to old fallback template"
  end
end
