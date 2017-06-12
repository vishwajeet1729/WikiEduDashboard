# frozen_string_literal: true

require "#{Rails.root}/lib/wiki_edits"

# Processes a RequestedAccount by creating a new mediawiki account, and
# creating the User record upon success.
class CreateRequestedAccount
  attr_reader :result, :user

  def initialize(requested_account, creator)
    @creator = creator
    @request_account = requested_account
    @course = requested_account.course
    @wiki = @course.home_wiki
    @username = requested_account.username
    @email = requested_account.email
    process_request
  end

  private

  def process_request
    course_link = "#{ENV['dashboard_url']}/courses/#{@course.slug}"
    creation_reason = I18n.t('wiki_api.create_account_reason', event: course_link)
    @response = WikiEdits.new(@wiki).create_account(creator: @creator,
                                                    username: @username,
                                                    email: @email,
                                                    reason: creation_reason)
    handle_mediawiki_response
  end

  # We only handle one-step PASS and FAIL statuses. For more complicated results,
  # such as an intermediate CAPTCHA step, we just fail immediately; users are expected
  # to have account creator rights on the target wiki, so that CAPTCHA is not required.
  def handle_mediawiki_response
    response_status = @response.dig('createaccount', 'status')
    if response_status == 'PASS'
      @result = { success: "Created account for #{@username} on #{@wiki.base_url}. A password will be emailed to #{@email}." }
      create_account
    elsif response_status == 'FAIL'
      @result = { failure: "Could not create account for #{@username} / #{@email}. #{@wiki.base_url} message: #{@response.dig('createaccount', 'messagecode')} — #{@response.dig('createaccount', 'message')}"}
    else
      @result = { failure: "Could not create account for #{@username} / #{@email}. #{@wiki.base_url} response: #{@response}" }
      log_unexpected_response
    end
  end

  def create_account
    returned_username = @response.dig('createaccount', 'username')
    raise AccountCreationError, 'no username returned' if returned_username.blank?
    @user = UserImporter.new_from_username(returned_username, @wiki)
    raise AccountCreationError, "could not create user #{returned_username}" if @user.blank?
  end

  def log_unexpected_response
    raise AccountCreationError, 'unexpected account creation response'
  rescue AccountCreationError => e
    Raven.capture_exception(e, extra: { response: @response })
  end

  class AccountCreationError < StandardError; end
end
