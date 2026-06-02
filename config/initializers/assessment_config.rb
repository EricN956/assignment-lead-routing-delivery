# Centralized runtime configuration for the lead routing assessment.
#
# Service objects should read from this config instead of hard-coding
# endpoint URLs, auth values, retry settings, or callback URLs.
assessment_config = Rails.application.config_for(:assessment).deep_symbolize_keys

Rails.application.config.x.assessment = assessment_config
