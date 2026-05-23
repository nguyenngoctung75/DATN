# # Smoke-test job for error notification. Remove before production deploy.
# class TestErrorJob < ApplicationJob
#   queue_as :default

#   def perform
#     raise StandardError, "Test job error at #{Time.current}"
#   end
# end
