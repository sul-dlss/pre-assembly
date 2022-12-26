# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base # rubocop:disable Style/Documentation
  default from: 'no-reply-preassembly@.stanford.edu'
  layout 'mailer'
end
