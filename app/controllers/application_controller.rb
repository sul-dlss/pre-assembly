class ApplicationController < ActionController::Base
  before_action :authenticate_user! # ensures that remote user is logged in locally (via database)
end
