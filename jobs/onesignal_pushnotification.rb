module Jobs
  class OnesignalPushnotification < Jobs::Base
    ONESIGNALAPI = 'https://onesignal.com/api/v1/notifications'.freeze

    def execute(args)
      payload = args['payload']
      # The user who should receive the notification
      # acted_on_user = args["user"]
      # The user who took action to trigger the notification
      actor_user = User.find_by(username: payload[:username])

      contents = payload[:excerpt]
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

      filters = [
        { "field": 'tag', "key": 'username', "relation": '=', "value": args['username'] }
      ]

      if SiteSetting.onesignal_rest_api_key.present?
        filters << { "field": 'tag', "key": 'env', "relation": '=', "value": SiteSetting.onesignal_rest_api_key }
      end

      params = {
        'app_id' => SiteSetting.onesignal_app_id,
        'contents' => { 'en' => contents },
        'headings' => { 'en' => heading },
        'data' => payload,
        'ios_badgeType' => 'Increase',
        'ios_badgeCount' => '1',
        'filters' => filters
      }

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
