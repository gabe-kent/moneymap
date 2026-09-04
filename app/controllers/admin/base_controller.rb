module Admin
  class BaseController < ApplicationController
    include AdminAuthorization
  end
end
