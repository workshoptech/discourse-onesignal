# name: discourse-onesignal
# about: Push notifications via the OneSignal API.
# version: 1.0
# authors: pmusaraj
# url: https://github.com/pmusaraj/discourse-onesignal

after_initialize do
  if SiteSetting.onesignal_push_enabled
    ONESIGNALAPI = 'https://onesignal.com/api/v1/notifications'

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

    module ::Jobs
      class OnesignalPushnotification < Jobs::Base
        def execute(args)
          payload = args["payload"]
          # The user who should receive the notification
          # acted_on_user = args["user"]
          # The user who took action to trigger the notification
          actor_user = User.find_by(username: payload[:username])
          
          heading = actor_user.name
          contents = payload[:excerpt]
          
          case payload[:notification_type]
          when 1
            # Mentioned: 1
            heading = "#{actor_user.name} mentioned you"
          when 2
            # Replied: 2
            heading = "#{actor_user.name} replied to you"
          when 3
            # Quoted: 3
            heading = "#{actor_user.name} quoted you"
          when 15
            # Group Mention: 15
            heading = "#{actor_user.name} mentioned your group"
          else
            # Private Message: 6
            # Posted: 9
            # Linked: 11
            heading = actor_user.name
            contents = payload[:excerpt]
          end

          filters = [
            { field: 'tag', key: 'username', relation: '=', value: args['username'] },
          ]

          if SiteSetting.onesignal_rest_api_key.present?
            Rails.logger.info("OneSignal filtering on environment env = #{SiteSetting.onesignal_rest_api_key}.")
            filters << { field: 'tag', key: 'env', relation: '=', value: SiteSetting.onesignal_rest_api_key }
          end

          params = {
            "app_id" => SiteSetting.onesignal_app_id,
            "contents" => {"en" => contents},
            "headings" => {"en" => heading},
            "data" => payload,
            "ios_badgeType" => "Increase",
            "ios_badgeCount" => "1",
            "filters" => filters,
            "android_group" => "workshop_discourse_onesignal",
            "thread_id" => "workshop_discourse_onesignal",
          }

          uri = URI.parse(ONESIGNALAPI)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true if uri.scheme == 'https'

          request = Net::HTTP::Post.new(uri.path,
              'Content-Type'  => 'application/json;charset=utf-8',
              'Authorization' => "Basic #{SiteSetting.onesignal_rest_api_key}")
          request.body = params.as_json.to_json
          response = http.request(request)

          case response
          when Net::HTTPSuccess then
            Rails.logger.info("Push notification sent via OneSignal to #{args['username']}.")
          else
            Rails.logger.error("OneSignal error")
            Rails.logger.error("#{request.to_yaml}")
            Rails.logger.error("#{response.to_yaml}")

          end

        end
      end
    end

  end
end
