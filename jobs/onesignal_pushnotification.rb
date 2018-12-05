module Jobs
  class OnesignalPushnotification < Jobs::Base
    ONESIGNALAPI = 'https://onesignal.com/api/v1/notifications'.freeze

    def execute(args)
      payload = args['payload']

      # The user who should receive the notification
      # acted_on_user = args["user"]
      # The user who took action to trigger the notification
      actor_user = User.find_by(username: payload[:username])

      # Get the post which triggered the notification
      post = Post.find_by('topic_id = :topic_id AND post_number = :post_number', topic_id: payload[:topic_id], post_number: payload[:post_number])

      heading = actor_user.name

      params = {
        'app_id' => SiteSetting.onesignal_app_id,
        'contents' => { 'en' => post.excerpt(400, text_entities: true, strip_links: true, remap_emoji: true) },
        'headings' => { 'en' => heading },
        'data' => payload,
        'ios_badgeType' => 'Increase',
        'ios_badgeCount' => '1',
        'filters' => [
          { "field": 'tag', "key": 'username', "relation": '=', "value": args['username'] }
        ]
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
