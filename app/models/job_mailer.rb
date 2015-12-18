class JobMailer < ActionMailer::Base
  def import_failed_email(user, error_details, zip)
    recipients  "Codexed Admin <admin+import_error@codexed.com>"
    from        "Codexed.com <automailer@codexed.com>"
    subject     "[cdx] Import job run by #{user.username} failed!"

    attachment :content_type => "application/zip" do |a|
      a.body = File.read(zip)
      a.filename = "archive.zip"
    end if zip

    part :content_type => "text/html" do |p|
      p.body = render_message("import_failed_email",
        :date => Time.now.strftime("%d %B %Y, %H:%M:%S %Z"),
        :username => user.username,
        :message => error_details.message,
        :backtrace => error_details.backtrace.join("\n")
      )
    end
  end
end
