# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'no-reply-preassembly@.stanford.edu'
  layout 'mailer'
end
