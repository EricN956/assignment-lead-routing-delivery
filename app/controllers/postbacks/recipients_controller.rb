module Postbacks
  class RecipientsController < ApplicationController
    skip_forgery_protection

    def create
      result = RecipientReceiver.call(request.request_parameters)

      render json: postback_response_body(result), status: result.http_status
    end

    private

    def postback_response_body(result)
      body = {
        status: result.status,
        message: result.message
      }

      body[:errors] = result.errors if result.invalid?
      body
    end
  end
end
