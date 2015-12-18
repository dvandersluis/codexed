class Mailer < ActionMailer::Base
  def user_activation_email(user, base_url)
    user.activation_email_sent_at = Time.now
    user.save!
    
    recipients user.email
    from "Codexed.com <automailer@codexed.com>"
    subject "#{I18n.t('mailer.cdx')} #{I18n.t('mailer.user_activation.subject')}"
    body(
      :user => user,
      :link => "#{base_url}verify/#{user.activation_key}"
    )
  end

  def user_forgot_password_email(user, base_url)
    recipients user.email
    from "Codexed.com <automailer@codexed.com>"
    subject "#{I18n.t('mailer.cdx')} #{I18n.t('mailer.forgot_password.subject')}"
    body(
      :user => user,
      :link => "#{base_url}reset_password/#{user.reset_password_key}"
    )
  end
end
