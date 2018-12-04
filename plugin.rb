# name: discourse-onesignal
# about: Push notifications via the OneSignal API.
# version: 1.0
# authors: pmusaraj
# url: https://github.com/pmusaraj/discourse-onesignal

after_initialize do
  if SiteSetting.onesignal_push_enabled
    ONESIGNALAPI = 'https://onesignal.com/api/v1/notifications'.freeze

    DiscourseEvent.on(:post_notification_alert) do |user, payload|
      Rails.logger.info('Post notification alert received for OneSignal plugin')

      if SiteSetting.onesignal_app_id.nil? || SiteSetting.onesignal_app_id.empty?
        Rails.logger.warn('OneSignal App ID is missing')
        return
      end
      if SiteSetting.onesignal_rest_api_key.nil? || SiteSetting.onesignal_rest_api_key.empty?
        Rails.logger.warn('OneSignal REST API Key is missing')
        return
      end
      
      Rails.logger.info('Queueing OnesignalPushnotification')
      Jobs.enqueue(:onesignal_pushnotification, payload: payload, username: user.username)
    end

    module ::Jobs
      class OnesignalPushnotification < Jobs::Base
        def execute(args)
          Rails.logger.info('OneSignal Push Notification starting')
          payload = args['payload']
          # The user who should receive the notification
          # acted_on_user = args["user"]
          # The user who took action to trigger the notification
          actor_user = User.find_by(username: payload[:username])

          Rails.logger.info("OneSignal Push Notification from user #{actor_user.name}")

          heading = case payload[:notification_type]
                    when 1
                      # Mentioned: 1
                      "#{actor_user.name} mentioned you"
                    when 2
                      # Replied: 2
                      "#{actor_user.name} replied to you"
                    when 3
                      # Quoted: 3
                      "#{actor_user.name} quoted you"
                    when 15
                      # Group Mention: 15
                      "#{actor_user.name} mentioned your group"
                    else
                      # Private Message: 6
                      # Posted: 9
                      # Linked: 11
                      actor_user.name
                    end
          Rails.logger.info("OneSignal Push Notification heading #{heading}")

          filters = [
            { field: 'tag', key: 'username', relation: '=', value: args['username'] }
          ]

          if SiteSetting.onesignal_rest_api_key.present?
            Rails.logger.info("OneSignal filtering on environment env = #{SiteSetting.onesignal_rest_api_key}.")
            filters << { field: 'tag', key: 'env', relation: '=', value: SiteSetting.onesignal_rest_api_key }
          end

          Rails.logger.info('OneSignal Push Notification building params')
          params = {
            'app_id' => SiteSetting.onesignal_app_id,
            'contents' => { 'en' => payload[:excerpt] },
            'headings' => { 'en' => heading },
            'data' => payload,
            'ios_badgeType' => 'Increase',
            'ios_badgeCount' => '1',
            'filters' => filters
          }
          Rails.logger.info('OneSignal Push Notification sending')
          uri = URI.parse(ONESIGNALAPI)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true if uri.scheme == 'https'

          request = Net::HTTP::Post.new(uri.path,
                                        'Content-Type' => 'application/json;charset=utf-8',
                                        'Authorization' => "Basic #{SiteSetting.onesignal_rest_api_key}")
          request.body = params.as_json.to_json
          response = http.request(request)

          case response
          when Net::HTTPSuccess then
            Rails.logger.info("Push notification sent via OneSignal to #{args['username']}.")
          else
            Rails.logger.error('OneSignal error')
            Rails.logger.error(request.to_yaml.to_s)
            Rails.logger.error(response.to_yaml.to_s)

          end
        end
      end
    end

  end
end
