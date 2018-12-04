# name: discourse-onesignal
# about: Push notifications via the OneSignal API.
# version: 1.0
# authors: pmusaraj
# url: https://github.com/pmusaraj/discourse-onesignal

after_initialize do
  if SiteSetting.onesignal_push_enabled
    ONESIGNALAPI = 'https://onesignal.com/api/v1/notifications'.freeze

    DiscourseEvent.on(:post_notification_alert) do |user, payload|
      if SiteSetting.onesignal_app_id.nil? || SiteSetting.onesignal_app_id.empty?
        Rails.logger.warn('OneSignal App ID is missing')
        return
      end
      if SiteSetting.onesignal_rest_api_key.nil? || SiteSetting.onesignal_rest_api_key.empty?
        Rails.logger.warn('OneSignal REST API Key is missing')
        return
      end

      Jobs.enqueue(:onesignal_pushnotification, payload: payload, username: user.username)
    end

  end
end
